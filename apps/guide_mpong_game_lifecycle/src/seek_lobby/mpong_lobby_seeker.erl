%%%-------------------------------------------------------------------
%%% @doc MPong lobby seeker — auto-joins games on LAN and mesh.
%%%
%%% Runs as a permanent child of guide_mpong_game_lifecycle_sup.
%%% Discovery sources:
%%% 1. pg group `mpong_lobby` — LAN/Erlang cluster lobbies
%%% 2. Mesh topic `mpong/game_advertised_v1` — remote mesh lobbies
%%%
%%% LAN flow:  pg cast `{reserve_spot, ...}` → host casts back
%%%            `{spot_reserved, ...}` or `{spot_denied, ...}`.
%%%
%%% Mesh flow: publish `seat_requested_v1` fact with a fresh request_id
%%%            → host publishes `seat_reserved_v1` or `seat_denied_v1`
%%%            with the same request_id → seeker correlates, joins or
%%%            falls back. Async pubsub instead of synchronous RPC so
%%%            the host doesn't saturate its gen_server queue under
%%%            burst joins.
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_lobby_seeker).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SEAT_REQUEST_TIMEOUT_MS, 5000).

-record(seeker, {
    champion              :: map() | undefined,
    joined_game           :: binary() | undefined,
    wall_index            :: non_neg_integer() | undefined,
    host_pid              :: pid() | undefined,
    %% Mesh subscriptions (one per topic).
    mesh_lobby_sub        :: reference() | undefined,
    mesh_reserved_sub     :: reference() | undefined,
    mesh_denied_sub       :: reference() | undefined,
    %% In-flight seat request — only one outstanding at a time.
    pending_request_id    :: binary() | undefined,
    pending_request_game  :: binary() | undefined
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

handle_info({mpong_state, GameId, StateMsg}, #seeker{joined_game = GameId} = State) ->
    hecate_web_events:broadcast(mpong_state, StateMsg),
    %% Check if match is over (best of 3: someone won 2 games)
    case maps:get(<<"games_won">>, StateMsg, maps:get(games_won, StateMsg, undefined)) of
        GamesWon when is_map(GamesWon) ->
            MaxWins = lists:max([0 | [V || V <- maps:values(GamesWon), is_integer(V)]]),
            case MaxWins >= 2 of
                true ->
                    logger:info("[mpong_seeker] Match over for ~s, ready for new games", [GameId]),
                    reset_state(State);
                false ->
                    {noreply, State}
            end;
        _ ->
            {noreply, State}
    end;
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
    %% Safety: auto-reset after 10 minutes in case game end is never detected
    erlang:send_after(600000, self(), {game_timeout, GameId}),
    {noreply, State#seeker{joined_game = GameId}};

handle_info({game_timeout, GameId}, #seeker{joined_game = GameId} = State) ->
    logger:info("[mpong_seeker] Game ~s timed out, resetting", [GameId]),
    reset_state(State);

handle_info({game_timeout, _OldGameId}, State) ->
    %% Already moved on to a different game or reset
    {noreply, State};

handle_info(try_mesh_subscribe,
            #seeker{mesh_lobby_sub = undefined} = State) ->
    case subscribe_mesh_topics() of
        {undefined, _, _} ->
            erlang:send_after(3000, self(), try_mesh_subscribe),
            {noreply, State};
        {LobbyRef, ReservedRef, DeniedRef} ->
            logger:info("[mpong_seeker] Mesh subscriptions active "
                        "(lobby + seat_reserved + seat_denied)"),
            {noreply, State#seeker{mesh_lobby_sub    = LobbyRef,
                                    mesh_reserved_sub = ReservedRef,
                                    mesh_denied_sub   = DeniedRef}}
    end;

handle_info(try_mesh_subscribe, State) ->
    %% Already subscribed
    {noreply, State};

%% Inbound seat_reserved fact — match by request_id to confirm acceptance.
handle_info({mpong_seat_reserved, Msg},
            #seeker{pending_request_id = Pending,
                    pending_request_game = PendingGame} = State)
  when Pending =/= undefined ->
    Payload = decode_payload(extract_payload(Msg)),
    case maps:get(<<"request_id">>, Payload, undefined) of
        Pending ->
            WallIndex = maps:get(<<"wall_index">>, Payload, undefined),
            logger:info("[mpong_seeker] seat reserved game=~s wall=~p",
                        [PendingGame, WallIndex]),
            self() ! {mesh_joined, PendingGame},
            {noreply, State#seeker{wall_index = WallIndex,
                                    pending_request_id = undefined,
                                    pending_request_game = undefined}};
        _ ->
            %% Reservation for someone else's request — ignore.
            {noreply, State}
    end;
handle_info({mpong_seat_reserved, _Msg}, State) ->
    {noreply, State};

%% Inbound seat_denied fact — match by request_id to clear pending.
handle_info({mpong_seat_denied, Msg},
            #seeker{pending_request_id = Pending,
                    pending_request_game = PendingGame} = State)
  when Pending =/= undefined ->
    Payload = decode_payload(extract_payload(Msg)),
    case maps:get(<<"request_id">>, Payload, undefined) of
        Pending ->
            Reason = maps:get(<<"reason">>, Payload, <<"unknown">>),
            logger:info("[mpong_seeker] seat denied game=~s reason=~s",
                        [PendingGame, Reason]),
            {noreply, State#seeker{pending_request_id = undefined,
                                    pending_request_game = undefined}};
        _ ->
            {noreply, State}
    end;
handle_info({mpong_seat_denied, _Msg}, State) ->
    {noreply, State};

%% Timeout for a pending seat request. If still pending under this
%% RequestId, clear so another advertise can trigger a new attempt.
handle_info({seat_request_timeout, RequestId},
            #seeker{pending_request_id = RequestId,
                    pending_request_game = PendingGame} = State) ->
    logger:info("[mpong_seeker] seat request timed out game=~s request_id=~s",
                [PendingGame, RequestId]),
    {noreply, State#seeker{pending_request_id = undefined,
                            pending_request_game = undefined}};
handle_info({seat_request_timeout, _OtherRequestId}, State) ->
    %% Stale timeout for a request that already completed.
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

terminate(_Reason, #seeker{mesh_lobby_sub = LobbySub,
                            mesh_reserved_sub = ReservedSub,
                            mesh_denied_sub = DeniedSub}) ->
    pg:leave(pg, mpong_lobby, self()),
    unsubscribe_mesh(LobbySub),
    unsubscribe_mesh(ReservedSub),
    unsubscribe_mesh(DeniedSub),
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
    Champion = get_our_champion(),
    try_request_seat(Champion, GameId, State);
handle_mesh_action(<<"closed">>, _HostNodeId, _OurNode, Msg, #seeker{joined_game = JG} = State) ->
    GameId = maps:get(<<"game_id">>, Msg, <<>>),
    case JG of
        GameId -> {noreply, State};  %% We're in this game, stay
        _      -> {noreply, State}   %% Not our game, ignore
    end;
handle_mesh_action(<<"ended">>, _HostNodeId, _OurNode, Msg, State) ->
    GameId = maps:get(<<"game_id">>, Msg, <<>>),
    case State#seeker.joined_game of
        GameId ->
            logger:info("[mpong_seeker] Game ~s ended (mesh event), resetting", [GameId]),
            reset_state(State);
        _ ->
            {noreply, State}
    end;
handle_mesh_action(_, _HostNodeId, _OurNode, _Msg, State) ->
    {noreply, State}.

try_request_seat(undefined, _GameId, State) ->
    {noreply, State};
try_request_seat(_Champion, _GameId,
                 #seeker{pending_request_id = Pending} = State)
  when Pending =/= undefined ->
    %% Already have an outstanding seat request — wait for response or
    %% timeout before issuing another. Avoids per-game-advertise spam.
    {noreply, State};
try_request_seat(Champion, GameId, State) ->
    RequestId = generate_request_id(),
    NodeId    = atom_to_binary(node()),
    Did       = own_did(),
    Topic     = hecate_topics:app_fact(<<"mpong">>, <<"seat_requested">>, 1),
    Event     = seat_requested_v1:new(RequestId, GameId, NodeId, Did,
                                      Champion,
                                      erlang:system_time(millisecond)),
    %% Pass the map, not json:encode'd — macula's V2 wire is CBOR.
    Payload   = seat_requested_v1:to_map(Event),
    case erlang:function_exported(hecate_mesh, publish, 2) of
        true  -> hecate_mesh:publish(Topic, Payload);
        false -> ok
    end,
    erlang:send_after(?SEAT_REQUEST_TIMEOUT_MS, self(),
                      {seat_request_timeout, RequestId}),
    logger:info("[mpong_seeker] requested seat in ~s request_id=~s",
                [GameId, RequestId]),
    {noreply, State#seeker{champion = Champion,
                           pending_request_id = RequestId,
                           pending_request_game = GameId}}.

generate_request_id() ->
    Bytes = crypto:strong_rand_bytes(8),
    %% Lowercase hex — 16 chars; plenty of entropy for at-most-one-in-flight.
    iolist_to_binary([io_lib:format("~2.16.0b", [B]) || <<B>> <= Bytes]).

own_did() ->
    case catch hecate_identity:get_mri() of
        {ok, Mri} -> Mri;
        _         -> atom_to_binary(node())
    end.

%%====================================================================
%% Internal: Mesh subscription
%%====================================================================

%% Subscribe to all three mesh topics in one go: game advertisements
%% (so we can request seats), seat_reserved (so we know we're in),
%% seat_denied (so we can give up promptly). Returns
%% {LobbyRef | undefined, ReservedRef | undefined, DeniedRef | undefined}
%% — if mesh isn't ready, returns {undefined, ...} so the caller retries.
subscribe_mesh_topics() ->
    Self = self(),
    case erlang:function_exported(hecate_mesh, subscribe, 2) of
        true ->
            LobbyTopic    = advertise_game:topic(),
            ReservedTopic = hecate_topics:app_fact(<<"mpong">>,
                                                   <<"seat_reserved">>, 1),
            DeniedTopic   = hecate_topics:app_fact(<<"mpong">>,
                                                   <<"seat_denied">>, 1),
            LobbyRef    = sub_or_undef(LobbyTopic,
                                       fun(M) -> Self ! {mesh_lobby, M}, ok end),
            ReservedRef = sub_or_undef(ReservedTopic,
                                       fun(M) -> Self ! {mpong_seat_reserved, M}, ok end),
            DeniedRef   = sub_or_undef(DeniedTopic,
                                       fun(M) -> Self ! {mpong_seat_denied, M}, ok end),
            {LobbyRef, ReservedRef, DeniedRef};
        false ->
            {undefined, undefined, undefined}
    end.

sub_or_undef(Topic, Callback) ->
    case hecate_mesh:subscribe(Topic, Callback) of
        {ok, Ref} -> Ref;
        _         -> undefined
    end.

extract_payload(#{payload := P}) -> P;
extract_payload(P)               -> P.

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

%% NAT classification (mapping/filtering policy) isn't surfaced by the
%% current macula transport — it will arrive with the macula-net
%% NAT-traversal work. Until then lobby tech metadata reports it as
%% unknown rather than calling a module that doesn't exist.
get_nat_type() ->
    <<"unknown">>.

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
