%%%-------------------------------------------------------------------
%%% @doc MPong lobby server — manages game formation on the host node.
%%%
%%% Supports two modes:
%%% - `lan`: Discovery via pg groups (Erlang cluster only)
%%% - `mesh`: Discovery via Macula mesh RPC + PubSub
%%%
%%% Lifecycle:
%%% 1. Host opens lobby → registers on pg (lan) or mesh (mesh)
%%% 2. Remote nodes join → seat assigned with tech metadata
%%% 3. All seats filled → countdown 3..2..1 → start engine
%%% 4. Engine running → lobby monitors engine, stops on exit
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_lobby_server).
-behaviour(gen_server).

-export([start_link/1, stop/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-include_lib("evoq/include/evoq.hrl").

-define(BROADCAST_MS, 2000).
-define(COUNTDOWN_SECS, 3).

-record(lobby, {
    game_id       :: binary(),
    host_node     :: binary(),
    host_champion :: map(),
    max_players   :: pos_integer(),
    mode          :: lan | mesh | mixed,
    seats         :: [seat()],
    state         :: waiting | countdown | playing,
    countdown     :: non_neg_integer(),
    broadcast_ref :: reference() | undefined,
    engine_pid    :: pid() | undefined,
    mesh_adv_ref  :: reference() | undefined
}).

-type seat() :: #{
    wall_index := non_neg_integer(),
    status := open | reserved,
    champion := map() | undefined,
    node_id := binary() | undefined,
    pid := pid() | undefined,
    tech := player_tech() | undefined
}.

-type player_tech() :: #{
    transport := lan | mesh,
    country := binary() | undefined,
    city := binary() | undefined,
    rtt_ms := non_neg_integer() | undefined,
    nat_type := binary() | undefined
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

init(#{game_id := GameId, max_players := MaxPlayers, host_champion := HostChampion} = Config) ->
    ensure_pg(),
    Mode = maps:get(mode, Config, lan),
    HostNode = atom_to_binary(node()),

    %% Host takes seat 0 with local tech info
    HostTech = #{transport => local, country => undefined, city => undefined,
                 rtt_ms => undefined, nat_type => <<"local">>},
    Seat0 = #{wall_index => 0, status => reserved,
              champion => HostChampion, node_id => HostNode, pid => self(),
              tech => HostTech},
    OpenSeats = [#{wall_index => I, status => open,
                   champion => undefined, node_id => undefined, pid => undefined,
                   tech => undefined}
                 || I <- lists:seq(1, MaxPlayers - 1)],
    Seats = [Seat0 | OpenSeats],

    %% Mode-gated registration
    {BroadcastRef, MeshAdvRef} = init_discovery(Mode, GameId, HostNode, MaxPlayers),

    logger:info("[mpong_lobby] Lobby opened: ~s (~b seats, mode=~s)",
                [GameId, MaxPlayers, Mode]),

    Lobby = #lobby{
        game_id = GameId,
        host_node = HostNode,
        host_champion = HostChampion,
        max_players = MaxPlayers,
        mode = Mode,
        seats = Seats,
        state = waiting,
        countdown = 0,
        broadcast_ref = BroadcastRef,
        mesh_adv_ref = MeshAdvRef
    },

    %% Always broadcast initial lobby state to local web UI
    hecate_web_events:broadcast(mpong_lobby, lobby_info(Lobby)),

    {ok, Lobby}.

handle_call(get_info, _From, State) ->
    {reply, lobby_info(State), State};

%% Mesh join (synchronous — returns accept/reject to caller)
handle_call({mesh_join, ChampionData, NodeId, Tech},
            _From, #lobby{state = waiting, mode = Mode, seats = Seats} = State)
  when Mode =:= mesh; Mode =:= mixed ->
    handle_mesh_reserve(ChampionData, NodeId, Tech, Seats, State);

handle_call({mesh_join, _ChampionData, _NodeId, _Tech}, _From, State) ->
    %% Not waiting or wrong mode — reject
    {reply, {ok, #{status => <<"rejected">>, reason => <<"lobby_not_accepting">>}}, State};

handle_call(_Req, _From, State) ->
    {reply, {error, unknown}, State}.

%% LAN join (with tech metadata) — accepted in lan and mixed modes
handle_cast({reserve_spot, FromPid, ChampionData, Tech},
            #lobby{state = waiting, mode = Mode} = State)
  when Mode =:= lan; Mode =:= mixed ->
    handle_reserve(FromPid, ChampionData, Tech, State);

%% LAN join (legacy 3-tuple, no tech)
handle_cast({reserve_spot, FromPid, ChampionData},
            #lobby{state = waiting, mode = Mode} = State)
  when Mode =:= lan; Mode =:= mixed ->
    Tech = #{transport => lan, country => undefined, city => undefined,
             rtt_ms => 0, nat_type => undefined},
    handle_reserve(FromPid, ChampionData, Tech, State);

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({init_mesh, GameId, HostNode, MaxPlayers},
            #lobby{state = waiting} = State) ->
    MeshAdvRef = advertise_join_rpc(GameId),
    case MeshAdvRef of
        undefined ->
            %% Mesh not ready — retry in 2 seconds
            erlang:send_after(2000, self(), {init_mesh, GameId, HostNode, MaxPlayers}),
            {noreply, State};
        _ ->
            advertise_game:announce(#{game_id => GameId, host_node_id => HostNode,
                                      max_players => MaxPlayers}),
            %% Re-announce periodically until lobby fills (same interval as LAN broadcast).
            %% A single announce is lost if boot restarts or subscribers join late.
            erlang:send_after(?BROADCAST_MS, self(), broadcast_mesh),
            {noreply, State#lobby{mesh_adv_ref = MeshAdvRef}}
    end;

handle_info({init_mesh, _GameId, _HostNode, _MaxPlayers}, State) ->
    %% No longer waiting — discard
    {noreply, State};

handle_info(broadcast_lobby, #lobby{state = waiting, mode = Mode} = State)
  when Mode =:= lan; Mode =:= mixed ->
    Members = try pg:get_members(pg, mpong_lobby) catch _:_ -> [] end,
    Info = lobby_info(State),
    [Pid ! {mpong_lobby_open, self(), Info} || Pid <- Members, Pid =/= self()],
    hecate_web_events:broadcast(mpong_lobby, Info),
    Ref = erlang:send_after(?BROADCAST_MS, self(), broadcast_lobby),
    {noreply, State#lobby{broadcast_ref = Ref}};

handle_info(broadcast_lobby, State) ->
    %% Not waiting or not lan mode — stop broadcasting
    {noreply, State};

handle_info(broadcast_mesh, #lobby{state = waiting, mode = Mode} = State)
  when Mode =:= mesh; Mode =:= mixed ->
    advertise_game:announce(#{game_id => State#lobby.game_id,
                              host_node_id => State#lobby.host_node,
                              max_players => State#lobby.max_players}),
    erlang:send_after(?BROADCAST_MS, self(), broadcast_mesh),
    {noreply, State};

handle_info(broadcast_mesh, State) ->
    %% Not waiting or not mesh mode — stop announcing
    {noreply, State};

handle_info(countdown_tick, #lobby{state = countdown, countdown = 1} = State) ->
    logger:info("[mpong_lobby] Countdown done, starting engine for ~s", [State#lobby.game_id]),
    broadcast_countdown(State#lobby.game_id, 0),
    start_engine(State);

handle_info(countdown_tick, #lobby{state = countdown, countdown = N} = State) ->
    logger:info("[mpong_lobby] Countdown: ~b for ~s", [N - 1, State#lobby.game_id]),
    broadcast_countdown(State#lobby.game_id, N - 1),
    erlang:send_after(1000, self(), countdown_tick),
    {noreply, State#lobby{countdown = N - 1}};

handle_info({'DOWN', _Ref, process, Pid, _Reason}, #lobby{engine_pid = Pid, game_id = GameId, mode = Mode} = State) ->
    logger:info("[mpong_lobby] Engine stopped for ~s, dispatching end_game", [GameId]),
    Cmd = end_game_v1:new(GameId, undefined, <<"engine_stopped">>),
    spawn(fun() -> maybe_end_game:dispatch(GameId, Cmd) end),
    %% Notify mesh that game ended — seekers reset their state
    case Mode of
        lan -> ok;
        _   -> advertise_game:ended(GameId)
    end,
    {stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #lobby{game_id = GameId, mode = Mode, mesh_adv_ref = MeshAdvRef}) ->
    cleanup_discovery(Mode, GameId, MeshAdvRef),
    logger:info("[mpong_lobby] Lobby closed: ~s (mode=~s)", [GameId, Mode]),
    ok.

%%====================================================================
%% Internal: Discovery init/cleanup (mode-gated)
%%====================================================================

init_discovery(lan, _GameId, _HostNode, _MaxPlayers) ->
    pg:join(pg, mpong_lobby, self()),
    Ref = erlang:send_after(?BROADCAST_MS, self(), broadcast_lobby),
    {Ref, undefined};
init_discovery(mesh, GameId, HostNode, MaxPlayers) ->
    self() ! {init_mesh, GameId, HostNode, MaxPlayers},
    {undefined, undefined};
init_discovery(mixed, GameId, HostNode, MaxPlayers) ->
    pg:join(pg, mpong_lobby, self()),
    Ref = erlang:send_after(?BROADCAST_MS, self(), broadcast_lobby),
    self() ! {init_mesh, GameId, HostNode, MaxPlayers},
    {Ref, undefined}.

cleanup_discovery(lan, _GameId, _MeshAdvRef) ->
    pg:leave(pg, mpong_lobby, self());
cleanup_discovery(mesh, GameId, MeshAdvRef) ->
    unadvertise_join_rpc(MeshAdvRef),
    advertise_game:withdraw(GameId);
cleanup_discovery(mixed, GameId, MeshAdvRef) ->
    pg:leave(pg, mpong_lobby, self()),
    unadvertise_join_rpc(MeshAdvRef),
    advertise_game:withdraw(GameId).

%%====================================================================
%% Internal: LAN reservation
%%====================================================================

handle_reserve(FromPid, ChampionData, Tech, #lobby{seats = Seats} = State) ->
    case find_open_seat(Seats) of
        {ok, WallIndex} ->
            RemoteNode = case node(FromPid) of
                nonode@nohost -> atom_to_binary(node());
                N -> atom_to_binary(N)
            end,
            ChampionName = maps:get(name, ChampionData, <<"Unknown">>),

            NewSeat = #{wall_index => WallIndex, status => reserved,
                        champion => ChampionData, node_id => RemoteNode,
                        pid => FromPid, tech => Tech},
            NewSeats = replace_seat(WallIndex, NewSeat, Seats),
            State2 = State#lobby{seats = NewSeats},

            FromPid ! {spot_reserved, State#lobby.game_id, WallIndex},

            logger:info("[mpong_lobby] ~s reserved seat ~b in ~s (lan, ~s)",
                        [ChampionName, WallIndex, State#lobby.game_id,
                         format_tech(Tech)]),

            hecate_web_events:broadcast(mpong_lobby, lobby_info(State2)),
            maybe_start_countdown(NewSeats, State2);
        full ->
            FromPid ! {spot_denied, State#lobby.game_id, full},
            {noreply, State}
    end.

%%====================================================================
%% Internal: Mesh reservation
%%====================================================================

handle_mesh_reserve(ChampionData, NodeId, Tech, Seats, State) ->
    case find_open_seat(Seats) of
        {ok, WallIndex} ->
            ChampionName = maps:get(<<"name">>, ChampionData,
                           maps:get(name, ChampionData, <<"Unknown">>)),
            NewSeat = #{wall_index => WallIndex, status => reserved,
                        champion => ChampionData, node_id => NodeId,
                        pid => undefined, tech => Tech},
            NewSeats = replace_seat(WallIndex, NewSeat, Seats),
            State2 = State#lobby{seats = NewSeats},

            logger:info("[mpong_lobby] ~s (mesh) reserved seat ~b in ~s (~s)",
                        [ChampionName, WallIndex, State#lobby.game_id,
                         format_tech(Tech)]),

            hecate_web_events:broadcast(mpong_lobby, lobby_info(State2)),
            Reply = {ok, #{status => <<"accepted">>, wall_index => WallIndex,
                           game_id => State#lobby.game_id}},
            case all_seats_filled(NewSeats) of
                true ->
                    logger:info("[mpong_lobby] All seats filled, starting countdown"),
                    erlang:send_after(1000, self(), countdown_tick),
                    broadcast_countdown(State#lobby.game_id, ?COUNTDOWN_SECS),
                    %% Publish lobby_closed to mesh so seekers know to stop trying
                    advertise_game:closed(State#lobby.game_id),
                    {reply, Reply,
                     State2#lobby{state = countdown, countdown = ?COUNTDOWN_SECS}};
                false ->
                    {reply, Reply, State2}
            end;
        full ->
            {reply, {ok, #{status => <<"rejected">>, reason => <<"full">>}}, State}
    end.

%% LAN still uses noreply variant
maybe_start_countdown(Seats, State) ->
    case all_seats_filled(Seats) of
        true ->
            logger:info("[mpong_lobby] All seats filled, starting countdown"),
            erlang:send_after(1000, self(), countdown_tick),
            broadcast_countdown(State#lobby.game_id, ?COUNTDOWN_SECS),
            {noreply, State#lobby{state = countdown, countdown = ?COUNTDOWN_SECS}};
        false ->
            {noreply, State}
    end.

%%====================================================================
%% Internal: Engine start
%%====================================================================

start_engine(#lobby{game_id = GameId, seats = Seats} = State) ->
    {PlayersMap, PlayerModes} = lists:foldl(fun(Seat, {PM, Modes}) ->
        #{wall_index := WI, champion := Champion, node_id := NId} = Seat,
        Name = maps:get(name, Champion, maps:get(<<"name">>, Champion, <<"bot">>)),
        PlayerId = <<Name/binary, "@", NId/binary>>,
        Personality = maps:get(personality, Champion, maps:get(<<"personality">>, Champion, #{})),
        {PM#{PlayerId => #{wall_index => WI}},
         Modes#{WI => {bot, Personality}}}
    end, {#{}, #{}}, Seats),

    %% Dispatch host → joins → start (aggregate requires this order)
    spawn(fun() ->
        HostCmd = host_game_v1:new(GameId, State#lobby.host_node, State#lobby.max_players),
        maybe_host_game:dispatch(HostCmd),
        lists:foreach(fun(Seat) ->
            dispatch_seat_join(GameId, Seat)
        end, Seats),
        StartCmd = start_game_v1:new(GameId, State#lobby.host_node),
        maybe_start_game:dispatch(GameId, StartCmd)
    end),

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
%% Internal: Serialization
%%====================================================================

lobby_info(#lobby{game_id = GameId, host_node = HostNode,
                  host_champion = HostChampion, max_players = MaxPlayers,
                  mode = Mode, seats = Seats, state = LobbyState, countdown = CD}) ->
    #{game_id => GameId,
      host_node => HostNode,
      host_champion_name => maps:get(name, HostChampion, <<"Unknown">>),
      max_players => MaxPlayers,
      mode => Mode,
      seats => [seat_info(S) || S <- Seats],
      state => LobbyState,
      countdown => CD,
      open_seats => length([S || #{status := open} = S <- Seats])}.

seat_info(#{wall_index := WI, status := Status, champion := undefined}) ->
    #{wall_index => WI, status => Status, champion_name => null, node_id => null,
      transport => null, country => null, city => null, rtt_ms => null, nat_type => null};
seat_info(#{wall_index := WI, status := Status, champion := C, node_id := NId, tech := Tech}) ->
    #{wall_index => WI, status => Status,
      champion_name => maps:get(name, C, maps:get(<<"name">>, C, <<"Unknown">>)),
      node_id => NId,
      transport => tech_field(transport, Tech),
      country => tech_field(country, Tech),
      city => tech_field(city, Tech),
      rtt_ms => tech_field(rtt_ms, Tech),
      nat_type => tech_field(nat_type, Tech)};
seat_info(#{wall_index := WI, status := Status, champion := C, node_id := NId}) ->
    #{wall_index => WI, status => Status,
      champion_name => maps:get(name, C, maps:get(<<"name">>, C, <<"Unknown">>)),
      node_id => NId,
      transport => null, country => null, city => null, rtt_ms => null, nat_type => null}.

tech_field(_Key, undefined) -> null;
tech_field(Key, Tech) -> maps:get(Key, Tech, null).

%%====================================================================
%% Internal: Helpers
%%====================================================================

dispatch_seat_join(GameId, #{wall_index := WI, champion := Champion, node_id := NId, tech := Tech}) ->
    Name = maps:get(name, Champion, maps:get(<<"name">>, Champion, <<"Unknown">>)),
    PlayerId = <<Name/binary, "@", NId/binary>>,
    Transport = tech_bin(transport, Tech),
    Country = tech_bin(country, Tech),
    City = tech_bin(city, Tech),
    RTT = case Tech of
        undefined -> undefined;
        _ -> case maps:find(rtt_ms, Tech) of
                {ok, R} -> R;
                error -> maps:get(<<"rtt_ms">>, Tech, undefined)
             end
    end,
    NatType = tech_bin(nat_type, Tech),
    StreamId = mpong_game_aggregate:stream_id(GameId),
    EvoqCmd = #evoq_command{
        command_type = join_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => join_game,
            game_id => GameId,
            player_node_id => PlayerId,
            champion_name => Name,
            transport => Transport,
            country => Country,
            city => City,
            rtt_ms => RTT,
            nat_type => NatType
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    case evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }) of
        {ok, _V, _Events} -> ok;
        {error, Reason} ->
            logger:warning("[mpong_lobby] Join dispatch failed for ~s wall ~b: ~p",
                           [Name, WI, Reason])
    end;
dispatch_seat_join(_GameId, _Seat) ->
    ok.

tech_bin(_Key, undefined) -> undefined;
tech_bin(Key, Tech) ->
    BinKey = atom_to_binary(Key),
    V = case maps:find(Key, Tech) of
        {ok, Val} -> Val;
        error ->
            case maps:find(BinKey, Tech) of
                {ok, Val} -> Val;
                error -> undefined
            end
    end,
    case V of
        A when is_atom(A), A =/= undefined -> atom_to_binary(A);
        _ -> V
    end.

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

format_tech(undefined) -> <<"no-tech">>;
format_tech(#{country := C, city := City, rtt_ms := RTT}) ->
    iolist_to_binary([
        case C of undefined -> <<>>; _ -> C end,
        case City of undefined -> <<>>; _ -> [<<" ">>, City] end,
        case RTT of undefined -> <<>>; _ -> [<<" ">>, integer_to_binary(RTT), <<"ms">>] end
    ]);
format_tech(_) -> <<"partial-tech">>.

%%====================================================================
%% Internal: Mesh RPC advertisement
%%====================================================================

advertise_join_rpc(GameId) ->
    try
        Procedure = advertise_game:join_procedure(GameId),
        Self = self(),
        Handler = fun(Args) ->
            ChampionData = maps:get(<<"champion">>, Args, #{}),
            NodeId = maps:get(<<"node_id">>, Args, <<"unknown">>),
            Tech = maps:get(<<"tech">>, Args, #{}),
            %% Synchronous call — returns actual accept/reject result
            try gen_server:call(Self, {mesh_join, ChampionData, NodeId, Tech}, 3000)
            catch _:_ -> {ok, #{status => <<"error">>, reason => <<"lobby_unavailable">>}}
            end
        end,
        case hecate_mesh:advertise(Procedure, Handler) of
            {ok, Ref} ->
                logger:info("[mpong_lobby] Mesh RPC registered: ~s", [Procedure]),
                Ref;
            {error, Reason} ->
                logger:warning("[mpong_lobby] Mesh RPC failed: ~p", [Reason]),
                undefined
        end
    catch
        Class:Err ->
            logger:warning("[mpong_lobby] Mesh advertise failed (~p:~p), will retry",
                           [Class, Err]),
            undefined
    end.

unadvertise_join_rpc(undefined) -> ok;
unadvertise_join_rpc(_Ref) -> ok.
