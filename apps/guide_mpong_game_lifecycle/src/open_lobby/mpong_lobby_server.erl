%%%-------------------------------------------------------------------
%%% @doc MPong lobby server — manages game formation on the host node.
%%%
%%% Lifecycle:
%%% 1. Host opens lobby → joins pg group, broadcasts lobby_open every 2s
%%% 2. Remote nodes send reserve_spot → host assigns wall_index
%%% 3. All seats filled → countdown 3..2..1 → start engine
%%% 4. Engine running → lobby server stops broadcasting, monitors engine
%%%
%%% pg groups used:
%%% - `mpong_lobby` — all lobbies broadcast here for discovery
%%% - `{mpong_game, GameId}` — game-specific state broadcast
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_lobby_server).
-behaviour(gen_server).

-export([start_link/1, stop/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(BROADCAST_MS, 2000).
-define(COUNTDOWN_SECS, 3).

-record(lobby, {
    game_id      :: binary(),
    host_node    :: binary(),
    host_champion :: map(),
    max_players  :: pos_integer(),
    seats        :: [seat()],
    state        :: waiting | countdown | playing,
    countdown    :: non_neg_integer(),
    broadcast_ref :: reference() | undefined,
    engine_pid   :: pid() | undefined
}).

-type seat() :: #{
    wall_index := non_neg_integer(),
    status := open | reserved,
    champion := map() | undefined,
    node_id := binary() | undefined,
    pid := pid() | undefined
}.

%%====================================================================
%% API
%%====================================================================

-spec start_link(map()) -> {ok, pid()} | {error, term()}.
start_link(Config) ->
    gen_server:start_link(?MODULE, Config, []).

stop(Pid) ->
    gen_server:stop(Pid).

%%====================================================================
%% gen_server
%%====================================================================

init(#{game_id := GameId, max_players := MaxPlayers, host_champion := HostChampion}) ->
    ensure_pg(),
    HostNode = atom_to_binary(node()),

    %% Host takes seat 0
    Seat0 = #{wall_index => 0, status => reserved,
              champion => HostChampion, node_id => HostNode, pid => self()},
    OpenSeats = [#{wall_index => I, status => open,
                   champion => undefined, node_id => undefined, pid => undefined}
                 || I <- lists:seq(1, MaxPlayers - 1)],
    Seats = [Seat0 | OpenSeats],

    %% Join lobby discovery group
    pg:join(pg, mpong_lobby, self()),

    %% Start broadcasting
    Ref = erlang:send_after(?BROADCAST_MS, self(), broadcast_lobby),

    logger:info("[mpong_lobby] Lobby opened: ~s (~b seats)", [GameId, MaxPlayers]),

    {ok, #lobby{
        game_id = GameId,
        host_node = HostNode,
        host_champion = HostChampion,
        max_players = MaxPlayers,
        seats = Seats,
        state = waiting,
        countdown = 0,
        broadcast_ref = Ref
    }}.

handle_call(get_info, _From, State) ->
    {reply, lobby_info(State), State};

handle_call(_Req, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast({reserve_spot, FromPid, ChampionData}, #lobby{state = waiting} = State) ->
    handle_reserve(FromPid, ChampionData, State);

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(broadcast_lobby, #lobby{state = waiting} = State) ->
    %% Broadcast to all nodes in the cluster
    Members = try pg:get_members(pg, mpong_lobby) catch _:_ -> [] end,
    Info = lobby_info(State),
    [Pid ! {mpong_lobby_open, self(), Info} || Pid <- Members, Pid =/= self()],

    %% Also broadcast to local web UI
    hecate_web_events:broadcast(mpong_lobby, Info),

    Ref = erlang:send_after(?BROADCAST_MS, self(), broadcast_lobby),
    {noreply, State#lobby{broadcast_ref = Ref}};

handle_info(broadcast_lobby, State) ->
    %% Not waiting anymore, stop broadcasting
    {noreply, State};

handle_info(countdown_tick, #lobby{state = countdown, countdown = 1} = State) ->
    %% Countdown finished — start engine
    logger:info("[mpong_lobby] Countdown done, starting engine for ~s", [State#lobby.game_id]),
    broadcast_countdown(State#lobby.game_id, 0),
    start_engine(State);

handle_info(countdown_tick, #lobby{state = countdown, countdown = N} = State) ->
    logger:info("[mpong_lobby] Countdown: ~b for ~s", [N - 1, State#lobby.game_id]),
    broadcast_countdown(State#lobby.game_id, N - 1),
    erlang:send_after(1000, self(), countdown_tick),
    {noreply, State#lobby{countdown = N - 1}};

handle_info({'DOWN', _Ref, process, Pid, _Reason}, #lobby{engine_pid = Pid} = State) ->
    logger:info("[mpong_lobby] Engine stopped for ~s, lobby closing", [State#lobby.game_id]),
    {stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #lobby{game_id = GameId}) ->
    pg:leave(pg, mpong_lobby, self()),
    logger:info("[mpong_lobby] Lobby closed: ~s", [GameId]),
    ok.

%%====================================================================
%% Internal: Reservation
%%====================================================================

handle_reserve(FromPid, ChampionData, #lobby{seats = Seats} = State) ->
    %% Find first open seat
    case find_open_seat(Seats) of
        {ok, WallIndex} ->
            RemoteNode = case node(FromPid) of
                nonode@nohost -> atom_to_binary(node());
                N -> atom_to_binary(N)
            end,
            ChampionName = maps:get(name, ChampionData, <<"Unknown">>),

            NewSeat = #{wall_index => WallIndex, status => reserved,
                        champion => ChampionData, node_id => RemoteNode, pid => FromPid},
            NewSeats = replace_seat(WallIndex, NewSeat, Seats),
            State2 = State#lobby{seats = NewSeats},

            %% Confirm to the remote
            FromPid ! {spot_reserved, State#lobby.game_id, WallIndex},

            logger:info("[mpong_lobby] ~s reserved seat ~b in ~s",
                        [ChampionName, WallIndex, State#lobby.game_id]),

            %% Broadcast updated lobby
            hecate_web_events:broadcast(mpong_lobby, lobby_info(State2)),

            %% Check if all seats filled
            case all_seats_filled(NewSeats) of
                true ->
                    logger:info("[mpong_lobby] All seats filled, starting countdown"),
                    erlang:send_after(1000, self(), countdown_tick),
                    broadcast_countdown(State2#lobby.game_id, ?COUNTDOWN_SECS),
                    {noreply, State2#lobby{state = countdown, countdown = ?COUNTDOWN_SECS}};
                false ->
                    {noreply, State2}
            end;
        full ->
            FromPid ! {spot_denied, State#lobby.game_id, full},
            {noreply, State}
    end.

%%====================================================================
%% Internal: Engine start
%%====================================================================

start_engine(#lobby{game_id = GameId, seats = Seats} = State) ->
    %% Build players map and player_modes from seats
    {PlayersMap, PlayerModes} = lists:foldl(fun(Seat, {PM, Modes}) ->
        #{wall_index := WI, champion := Champion, node_id := NId} = Seat,
        Name = maps:get(name, Champion, <<"bot">>),
        PlayerId = <<Name/binary, "@", NId/binary>>,
        Personality = maps:get(personality, Champion, #{}),
        {PM#{PlayerId => #{wall_index => WI}},
         Modes#{WI => {bot, Personality}}}
    end, {#{}, #{}}, Seats),

    %% Write game to projection store so frontend can find it
    Players = [#{node_id => PId, wall_index => maps:get(wall_index, PInfo), alive => true,
                 joined_at => erlang:system_time(millisecond)}
               || {PId, PInfo} <- maps:to_list(PlayersMap)],
    project_mpong_games_store:put(GameId, #{
        game_id => GameId,
        host_node_id => State#lobby.host_node,
        players => Players,
        max_players => State#lobby.max_players,
        status => <<"playing">>,
        hosted_at => erlang:system_time(millisecond),
        started_at => erlang:system_time(millisecond),
        ended_at => null,
        winner_node_id => null
    }),

    case run_game_engine_sup:start_engine(#{
        game_id => GameId,
        players => PlayersMap,
        player_modes => PlayerModes
    }) of
        {ok, EnginePid} ->
            erlang:monitor(process, EnginePid),
            {noreply, State#lobby{state = playing, engine_pid = EnginePid}};
        {error, Reason} ->
            logger:error("[mpong_lobby] Failed to start engine: ~p", [Reason]),
            {stop, {engine_failed, Reason}, State}
    end.

%%====================================================================
%% Internal: Helpers
%%====================================================================

lobby_info(#lobby{game_id = GameId, host_node = HostNode,
                  host_champion = HostChampion, max_players = MaxPlayers,
                  seats = Seats, state = LobbyState, countdown = CD}) ->
    #{game_id => GameId,
      host_node => HostNode,
      host_champion_name => maps:get(name, HostChampion, <<"Unknown">>),
      max_players => MaxPlayers,
      seats => [seat_info(S) || S <- Seats],
      state => LobbyState,
      countdown => CD,
      open_seats => length([S || #{status := open} = S <- Seats])}.

seat_info(#{wall_index := WI, status := Status, champion := undefined}) ->
    #{wall_index => WI, status => Status, champion_name => null, node_id => null};
seat_info(#{wall_index := WI, status := Status, champion := C, node_id := NId}) ->
    #{wall_index => WI, status => Status,
      champion_name => maps:get(name, C, <<"Unknown">>),
      node_id => NId}.

find_open_seat([]) -> full;
find_open_seat([#{status := open, wall_index := WI} | _]) -> {ok, WI};
find_open_seat([_ | Rest]) -> find_open_seat(Rest).

all_seats_filled(Seats) ->
    lists:all(fun(#{status := S}) -> S =:= reserved end, Seats).

replace_seat(WI, NewSeat, Seats) ->
    lists:map(fun(#{wall_index := W} = S) ->
        case W =:= WI of true -> NewSeat; false -> S end
    end, Seats).

broadcast_countdown(GameId, N) ->
    hecate_web_events:broadcast(mpong_countdown, #{game_id => GameId, countdown => N}).

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
