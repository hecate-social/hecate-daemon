%%%-------------------------------------------------------------------
%%% @doc MPong lobby seeker — auto-joins games on the LAN cluster.
%%%
%%% Runs as a permanent child of guide_mpong_game_lifecycle_sup.
%%% Joins pg group `mpong_lobby` and listens for lobby_open broadcasts.
%%% When an open lobby is found, reserves a spot with our champion.
%%% When game starts, forwards state to local hecate_web_events for UI.
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_lobby_seeker).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(seeker, {
    champion   :: map() | undefined,
    joined_game :: binary() | undefined,
    wall_index :: non_neg_integer() | undefined,
    host_pid   :: pid() | undefined
}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    ensure_pg(),
    pg:join(pg, mpong_lobby, self()),
    logger:info("[mpong_seeker] Listening for lobbies on pg group"),
    {ok, #seeker{}}.

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Lobby broadcast from a host node
handle_info({mpong_lobby_open, HostPid, LobbyInfo}, #seeker{joined_game = undefined} = State) ->
    %% Not in a game yet — try to join if there's an open seat
    OpenSeats = maps:get(open_seats, LobbyInfo, 0),
    GameId = maps:get(game_id, LobbyInfo, <<>>),
    HostNode = maps:get(host_node, LobbyInfo, <<>>),
    OurNode = atom_to_binary(node()),

    case {OpenSeats > 0, HostNode =/= OurNode} of
        {true, true} ->
            %% Different node has an open lobby — try to join
            Champion = get_our_champion(),
            case Champion of
                undefined ->
                    %% No champion yet, skip
                    {noreply, State};
                C ->
                    logger:info("[mpong_seeker] Found lobby ~s on ~s, reserving spot",
                                [GameId, HostNode]),
                    gen_server:cast(HostPid, {reserve_spot, self(), C}),
                    {noreply, State#seeker{champion = C, host_pid = HostPid}}
            end;
        _ ->
            %% Our own lobby or full — ignore
            {noreply, State}
    end;

%% Already in a game — ignore other lobbies
handle_info({mpong_lobby_open, _HostPid, _LobbyInfo}, State) ->
    {noreply, State};

%% Spot confirmed by host
handle_info({spot_reserved, GameId, WallIndex}, State) ->
    logger:info("[mpong_seeker] Spot reserved in ~s at wall ~b", [GameId, WallIndex]),
    %% Join game pg group to receive state broadcasts
    pg:join(pg, {mpong_game, GameId}, self()),
    hecate_web_events:broadcast(mpong_lobby_joined, #{game_id => GameId, wall_index => WallIndex}),
    {noreply, State#seeker{joined_game = GameId, wall_index = WallIndex}};

%% Spot denied
handle_info({spot_denied, GameId, Reason}, State) ->
    logger:info("[mpong_seeker] Spot denied in ~s: ~p", [GameId, Reason]),
    {noreply, State#seeker{host_pid = undefined}};

%% Countdown from host
handle_info({mpong_countdown, _GameId, _N}, State) ->
    %% Frontend handles countdown display via hecate_web_events (host already broadcasts)
    {noreply, State};

%% Game state from engine (via pg group)
handle_info({mpong_state, _GameId, StateMsg}, State) ->
    %% Forward to local web UI
    hecate_web_events:broadcast(mpong_state, StateMsg),
    {noreply, State};

%% Game ended — reset seeker to listen for new games
handle_info({'DOWN', _Ref, process, Pid, _Reason}, #seeker{host_pid = Pid} = State) ->
    logger:info("[mpong_seeker] Host lobby process died, ready for new games"),
    reset_state(State);

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    pg:leave(pg, mpong_lobby, self()),
    ok.

%%====================================================================
%% Internal
%%====================================================================

get_our_champion() ->
    NodeId = atom_to_binary(node()),
    case ets:info(mpong_champions) of
        undefined -> undefined;
        _ ->
            case ets:lookup(mpong_champions, NodeId) of
                [{_, Champion}] -> Champion;
                [] -> undefined
            end
    end.

reset_state(#seeker{joined_game = GameId} = _State) ->
    case GameId of
        undefined -> ok;
        GId -> pg:leave(pg, {mpong_game, GId}, self())
    end,
    {noreply, #seeker{}}.

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.
