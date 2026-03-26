%%%-------------------------------------------------------------------
%%% @doc MPong lobby seeker — auto-joins games on LAN and mesh.
%%%
%%% Runs as a permanent child of guide_mpong_game_lifecycle_sup.
%%% Discovery sources:
%%% 1. pg group `mpong_lobby` — LAN/Erlang cluster lobbies
%%% 2. Mesh topic `mpong.games.available` — remote mesh lobbies
%%%
%%% For LAN: reserves spot via direct gen_server:cast (pg PID)
%%% For Mesh: reserves spot via mesh RPC call to join procedure
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_lobby_seeker).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(seeker, {
    champion    :: map() | undefined,
    joined_game :: binary() | undefined,
    wall_index  :: non_neg_integer() | undefined,
    host_pid    :: pid() | undefined,
    mesh_sub    :: reference() | undefined
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

    %% Defer mesh subscription — mesh client may not be connected yet
    self() ! try_mesh_subscribe,

    %% Periodically try connecting to peer dev nodes (every 10s until connected)
    erlang:send_after(3000, self(), try_connect_peers),
    logger:info("[mpong_seeker] Listening for lobbies on pg + mesh"),
    {ok, #seeker{}}.

handle_call(_Req, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% ---- LAN lobby broadcast (from pg group) ----

handle_info({mpong_lobby_open, HostPid, LobbyInfo}, #seeker{joined_game = undefined} = State) ->
    OpenSeats = maps:get(open_seats, LobbyInfo, 0),
    GameId = maps:get(game_id, LobbyInfo, <<>>),
    HostNode = maps:get(host_node, LobbyInfo, <<>>),
    OurNode = atom_to_binary(node()),

    case {OpenSeats > 0, HostNode =/= OurNode} of
        {true, true} ->
            Champion = get_our_champion(),
            try_lan_join(Champion, GameId, HostNode, HostPid, State);
        _ ->
            {noreply, State}
    end;

handle_info({mpong_lobby_open, _HostPid, _LobbyInfo}, State) ->
    {noreply, State};

%% ---- Mesh lobby announcement ----

handle_info({mesh_lobby, Payload}, #seeker{joined_game = undefined} = State) ->
    handle_mesh_lobby(Payload, State);

handle_info({mesh_lobby, _Payload}, State) ->
    {noreply, State};

%% ---- Spot confirmed by LAN host ----

handle_info({spot_reserved, GameId, WallIndex}, #seeker{host_pid = HostPid} = State) ->
    logger:info("[mpong_seeker] Spot reserved in ~s at wall ~b", [GameId, WallIndex]),
    erlang:monitor(process, HostPid),
    pg:join(pg, {mpong_game, GameId}, self()),
    hecate_web_events:broadcast(mpong_lobby_joined, #{game_id => GameId, wall_index => WallIndex}),
    {noreply, State#seeker{joined_game = GameId, wall_index = WallIndex}};

handle_info({spot_denied, GameId, Reason}, State) ->
    logger:info("[mpong_seeker] Spot denied in ~s: ~p", [GameId, Reason]),
    {noreply, State#seeker{host_pid = undefined}};

%% ---- Game state forwarding ----

handle_info({mpong_countdown, _GameId, _N}, State) ->
    {noreply, State};

handle_info({mpong_state, _GameId, StateMsg}, State) ->
    hecate_web_events:broadcast(mpong_state, StateMsg),
    {noreply, State};

%% ---- Lifecycle ----

handle_info({'DOWN', _Ref, process, Pid, _Reason}, #seeker{host_pid = Pid} = State) ->
    logger:info("[mpong_seeker] Host lobby process died, ready for new games"),
    reset_state(State);

%% Mesh join confirmation — start listening for game state over mesh
handle_info({mesh_joined, GameId}, #seeker{} = State) ->
    logger:info("[mpong_seeker] Mesh game joined: ~s, starting state listener", [GameId]),
    hecate_web_events:broadcast(mpong_lobby_joined, #{game_id => GameId, wall_index => undefined}),
    listen_game_state_sup:start_listener(#{game_id => GameId, wall_index => 1}),
    {noreply, State#seeker{joined_game = GameId}};

handle_info(try_mesh_subscribe, #seeker{mesh_sub = undefined} = State) ->
    case subscribe_mesh_lobbies() of
        undefined ->
            erlang:send_after(3000, self(), try_mesh_subscribe),
            {noreply, State};
        Ref ->
            logger:info("[mpong_seeker] Mesh subscription active"),
            {noreply, State#seeker{mesh_sub = Ref}}
    end;

handle_info(try_mesh_subscribe, State) ->
    %% Already subscribed
    {noreply, State};

handle_info(try_connect_peers, State) ->
    Connected = try_connect_dev_peers(),
    case Connected of
        0 -> erlang:send_after(10000, self(), try_connect_peers);
        _ -> ok
    end,
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #seeker{mesh_sub = MeshSub}) ->
    pg:leave(pg, mpong_lobby, self()),
    unsubscribe_mesh(MeshSub),
    ok.

%%====================================================================
%% Internal: LAN join
%%====================================================================

try_lan_join(undefined, _GameId, _HostNode, _HostPid, State) ->
    {noreply, State};
try_lan_join(Champion, GameId, HostNode, HostPid, State) ->
    Tech = collect_tech(lan),
    logger:info("[mpong_seeker] Found LAN lobby ~s on ~s, reserving spot",
                [GameId, HostNode]),
    gen_server:cast(HostPid, {reserve_spot, self(), Champion, Tech}),
    {noreply, State#seeker{champion = Champion, host_pid = HostPid}}.

%%====================================================================
%% Internal: Mesh join
%%====================================================================

handle_mesh_lobby(PublishData, State) ->
    %% PublishData from macula is #{topic => ..., payload => DecodedPayload}
    %% Extract the actual game announcement from the payload field
    RawPayload = case PublishData of
        #{payload := P} -> P;
        _ -> PublishData
    end,
    Msg = decode_payload(RawPayload),
    Action = maps:get(<<"action">>, Msg, undefined),
    HostNodeId = maps:get(<<"host_node_id">>, Msg, <<>>),
    OurNode = atom_to_binary(node()),
    handle_mesh_action(Action, HostNodeId, OurNode, Msg, State).

handle_mesh_action(<<"hosted">>, HostNodeId, OurNode, _Msg, State)
  when HostNodeId =:= OurNode ->
    %% Our own lobby — ignore
    {noreply, State};
handle_mesh_action(<<"hosted">>, _HostNodeId, _OurNode, Msg, State) ->
    GameId = maps:get(<<"game_id">>, Msg, <<>>),
    JoinProcedure = maps:get(<<"join_procedure">>, Msg, undefined),
    Champion = get_our_champion(),
    try_mesh_join(Champion, JoinProcedure, GameId, State);
handle_mesh_action(_, _HostNodeId, _OurNode, _Msg, State) ->
    {noreply, State}.

try_mesh_join(undefined, _JoinProcedure, _GameId, State) ->
    {noreply, State};
try_mesh_join(_Champion, undefined, _GameId, State) ->
    {noreply, State};
try_mesh_join(Champion, JoinProcedure, GameId, State) ->
    logger:info("[mpong_seeker] Found mesh lobby ~s, joining via RPC ~s",
                [GameId, JoinProcedure]),
    %% Spawn the mesh RPC call to avoid blocking the seeker
    Self = self(),
    spawn(fun() ->
        Tech = collect_tech(mesh),
        Args = #{
            <<"champion">> => Champion,
            <<"node_id">> => atom_to_binary(node()),
            <<"tech">> => Tech
        },
        T0 = erlang:monotonic_time(millisecond),
        case hecate_mesh:call(JoinProcedure, Args, 5000) of
            {ok, _Result} ->
                RTT = erlang:monotonic_time(millisecond) - T0,
                logger:info("[mpong_seeker] Mesh join accepted for ~s (RTT: ~bms)", [GameId, RTT]),
                Self ! {mesh_joined, GameId};
            {error, Reason} ->
                logger:warning("[mpong_seeker] Mesh join failed for ~s: ~p",
                               [GameId, Reason])
        end
    end),
    {noreply, State#seeker{champion = Champion}}.

%%====================================================================
%% Internal: Mesh subscription
%%====================================================================

subscribe_mesh_lobbies() ->
    Self = self(),
    case erlang:function_exported(hecate_mesh, subscribe, 2) of
        true ->
            case hecate_mesh:subscribe(advertise_game:topic(),
                                       fun(Msg) -> Self ! {mesh_lobby, Msg}, ok end) of
                {ok, Ref} -> Ref;
                _ -> undefined
            end;
        false ->
            undefined
    end.

unsubscribe_mesh(undefined) -> ok;
unsubscribe_mesh(Ref) ->
    case erlang:function_exported(hecate_mesh, unsubscribe, 1) of
        true -> hecate_mesh:unsubscribe(Ref);
        false -> ok
    end.

%%====================================================================
%% Internal: Tech metadata collection
%%====================================================================

collect_tech(Transport) ->
    {Country, City} = get_geo(),
    NatType = get_nat_type(),
    #{transport => Transport,
      country => Country,
      city => City,
      rtt_ms => undefined,
      nat_type => NatType}.

get_geo() ->
    case catch geo_check:get_public_ip() of
        {ok, IP} -> get_geo_location(IP);
        _ -> {undefined, undefined}
    end.

get_geo_location(IP) ->
    case catch geo_check:get_location(IP) of
        {ok, #{country := C, city := City}} -> {C, City};
        _ -> {undefined, undefined}
    end.

get_nat_type() ->
    case catch macula_nat_detector:get_local_profile() of
        {ok, #{mapping_policy := M, filtering_policy := F}} ->
            iolist_to_binary(io_lib:format("~s/~s", [M, F]));
        _ ->
            <<"unknown">>
    end.

%%====================================================================
%% Internal: Helpers
%%====================================================================

decode_payload(Payload) when is_binary(Payload) ->
    try json:decode(Payload) catch _:_ -> #{} end;
decode_payload(Payload) when is_map(Payload) ->
    Payload;
decode_payload(_) ->
    #{}.

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

%% @private Try connecting to known dev peer nodes.
%% Returns count of new connections made.
try_connect_dev_peers() ->
    OurNode = atom_to_list(node()),
    {_Names, Host} = case string:split(OurNode, "@") of
        [Name, H] -> {Name, H};
        _ -> {OurNode, "localhost"}
    end,
    Prefixes = ["hecate_dev", "hecate_dev0", "hecate_dev1", "hecate_dev2"],
    Candidates = [list_to_atom(P ++ "@" ++ Host) || P <- Prefixes],
    Peers = [N || N <- Candidates, N =/= node()],
    lists:foldl(fun(Peer, Count) ->
        case net_kernel:connect_node(Peer) of
            true ->
                logger:info("[mpong_seeker] Connected to peer ~s", [Peer]),
                Count + 1;
            _ ->
                Count
        end
    end, 0, Peers).
