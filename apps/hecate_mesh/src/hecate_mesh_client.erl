%%%-------------------------------------------------------------------
%%% @doc Hecate mesh client — local-first, activate-on-demand.
%%%
%%% Starts in local mode (no network). Domain apps register
%%% subscriptions and advertisements immediately. Actual QUIC
%%% connections are established only when activate/0 is called
%%% (triggered by POST /api/mesh/activate from the web UI).
%%%
%%% On activation: builds a V2 `macula_client' pool, drains pending
%%% registrations, runs mesh proof ceremony. Streaming RPC, pubsub,
%%% and non-stream RPC all ride the same pool. DHT ops still go
%%% through a parallel direct `macula_station_link' pool because
%%% the SDK facade does not yet expose `put_record' at the pool
%%% level.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, activate/0, is_activated/0, get_client/0]).
-export([connected_peer_pubkeys/0]).
-export([get_status/0, publish/2, subscribe/2,
         unsubscribe/1, discover_subscribers/1, advertise/2, call/3, call/4,
         put_record/1, find_record/1, find_records_by_type/1,
         put_content/1, get_content/1]).
-export([register_subscription/2, register_advertisement/2,
         unregister_advertisement/1,
         register_stream_advertisement/3, call_stream/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    %% V2 `macula_client' pool — covers pubsub, streaming RPC,
    %% non-stream RPC, and procedure advertisements (one pool, N
    %% station_links inside it, realm-per-call).
    pool :: pid() | undefined,
    activated :: boolean(),
    realm :: binary(),
    relays :: [binary()],
    connections :: pos_integer(),
    site :: map(),
    pending_subs :: [{binary(), fun()}],
    pending_advs :: [{binary(), fun()}],
    pending_stream_advs = [] :: [{binary(), atom(), fun()}],
    %% Direct `macula_station_link' pool — one per relay URL. Used
    %% only for DHT ops (put_record / find_record /
    %% find_records_by_type) which the SDK pool facade does not yet
    %% expose. Everything else routes through `pool' above.
    station_clients   = #{} :: #{binary() => pid()},
    station_monitors  = #{} :: #{reference() => binary()}
}).

%% Backoff between respawning a single dead station-client. Short
%% enough that a transient peering loss recovers within a poll cycle.
-define(STATION_RESPAWN_MS, 5_000).
%% Per-call deadline on DHT ops. Generous — first call after
%% start_link blocks until peering CONNECT/HELLO completes.
-define(STATION_DHT_TIMEOUT_MS, 8_000).

%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Activate mesh — connect to relays and drain pending registrations.
%% Called by POST /api/mesh/activate after the UI is up.
-spec activate() -> ok | {error, already_activated}.
activate() ->
    gen_server:call(?MODULE, activate, 30000).

-spec is_activated() -> boolean().
is_activated() ->
    %% Read from persistent_term (lock-free) to avoid blocking on the
    %% gen_server queue during boot contention. The activate/deactivate
    %% transitions update the flag inside handle_call so a legitimate
    %% stale read can only happen during the exact instant of transition,
    %% which is acceptable for this probe-style use.
    persistent_term:get({?MODULE, activated}, false).

%% @doc Return the live V2 `macula_client' pool pid for direct SDK
%% calls (`macula:find_record/2', `macula:subscribe_records/3',
%% `macula:publish/4', ...). Used by the DNS-over-mesh listeners and
%% the resolve_mesh_names cache-invalidation PMs.
%%
%% Lock-free read from persistent_term, mirroring `is_activated/0' —
%% never blocks on this gen_server's call queue (which can be held by
%% an in-progress `activate/0' for several seconds). Returns
%% `{error, not_activated}' until `activate/0' has built the pool, and
%% again after a pool death until reactivation rebuilds it.
-spec get_client() -> {ok, pid()} | {error, not_activated}.
get_client() ->
    case persistent_term:get({?MODULE, pool}, undefined) of
        Pool when is_pid(Pool) -> {ok, Pool};
        _                      -> {error, not_activated}
    end.

%% @doc Register a subscription to be applied when mesh activates.
%% Returns immediately. Safe to call during init/1.
-spec register_subscription(binary(), fun()) -> ok.
register_subscription(Topic, Callback) ->
    gen_server:cast(?MODULE, {register_sub, Topic, Callback}).

%% @doc Register an advertisement to be applied when mesh activates.
%% Returns immediately. Safe to call during init/1.
-spec register_advertisement(binary(), fun()) -> ok.
register_advertisement(Procedure, Handler) ->
    gen_server:cast(?MODULE, {register_adv, Procedure, Handler}).

%% @doc Register a streaming-RPC advertisement to be applied when mesh
%% activates. Mirrors register_advertisement/2 for the streaming surface
%% added in macula 1.5.x. Mode is server_stream | client_stream | bidi.
-spec register_stream_advertisement(binary(), atom(),
        fun((pid(), term()) -> any())) -> ok.
register_stream_advertisement(Procedure, Mode, Handler) ->
    gen_server:cast(?MODULE, {register_stream_adv, Procedure, Mode, Handler}).

%% @doc Open a streaming RPC against a remote procedure. Returns the
%% client-side macula_stream pid. Caller drains chunks with
%% macula:recv/1,2 or sends with macula:send/2,3.
-spec call_stream(binary(), term(), map(), timeout()) ->
        {ok, pid()} | {error, term()}.
call_stream(Procedure, Args, _Opts, Timeout) ->
    gen_server:call(?MODULE, {call_stream, Procedure, Args, Timeout},
                    Timeout + 1000).

%% @doc Retract a previously-registered advertisement.
%% When the mesh isn't activated yet this clears any pending entry.
%% Safe to call from any process.
-spec unregister_advertisement(binary()) -> ok.
unregister_advertisement(Procedure) ->
    gen_server:cast(?MODULE, {unregister_adv, Procedure}).

publish(Topic, Payload) ->
    gen_server:call(?MODULE, {publish, Topic, Payload}).

%% @doc Put a signed `macula_record:record()' into the mesh DHT.
%% PLAN_DHT_FIRST.md — emitters use this instead of `publish/2' so
%% their facts survive station-side state-replication regardless of
%% pub/sub fan-out.
-spec put_record(macula_record:record()) -> ok | {error, term()}.
put_record(Record) when is_map(Record) ->
    %% Worker timeout = STATION_DHT_TIMEOUT_MS (8s); add cushion so
    %% the caller doesn't `exit({timeout, _})' before the worker has
    %% had its chance to reply with a clean `{error, timeout}'.
    safe_call({put_record, Record}, ?STATION_DHT_TIMEOUT_MS + 5_000).

%% @doc Fetch a signed record by its `macula_record:storage_key/1'.
-spec find_record(<<_:256>>) -> {ok, macula_record:record()} | {error, term()}.
find_record(Key) when is_binary(Key), byte_size(Key) =:= 32 ->
    safe_call({find_record, Key}, ?STATION_DHT_TIMEOUT_MS + 5_000).

%% @doc List every locally-known signed record of a given type tag.
%% Coverage is the connected station's local view; cross-station
%% completeness requires polling multiple seeds.
-spec find_records_by_type(macula_record:type_tag()) ->
        {ok, [macula_record:record()]} | {error, term()}.
find_records_by_type(Type) when is_integer(Type), Type >= 1, Type =< 16#FF ->
    safe_call({find_records_by_type, Type}, ?STATION_DHT_TIMEOUT_MS + 5_000).

%% @doc Store bytes via the SDK pool's content-sharing primitive.
%%
%% Routes through `macula:put_content/2' on the V2 pool — same pool used
%% for pubsub/RPC. Surfaces `{error, not_activated}' until the pool is
%% built (post-activation). The MCID is BLAKE3-derived from the bytes.
-spec put_content(binary()) -> {ok, binary()} | {error, term()}.
put_content(Bytes) when is_binary(Bytes) ->
    case get_client() of
        {ok, Pool} -> macula:put_content(Pool, Bytes);
        Error      -> Error
    end.

%% @doc Fetch bytes by MCID via the SDK pool.
-spec get_content(binary()) -> {ok, binary()} | {error, term()}.
get_content(<<1, 16#55, _:32/binary>> = MCID) ->
    case get_client() of
        {ok, Pool} -> macula:get_content(Pool, MCID);
        Error      -> Error
    end;
get_content(_) ->
    {error, invalid_mcid}.

subscribe(Topic, Callback) ->
    gen_server:call(?MODULE, {subscribe, Topic, Callback}).

unsubscribe(SubRef) ->
    gen_server:call(?MODULE, {unsubscribe, SubRef}).

advertise(Procedure, Handler) ->
    gen_server:call(?MODULE, {advertise, Procedure, Handler}).

call(Procedure, Args, Timeout) ->
    gen_server:call(?MODULE, {rpc_call, Procedure, Args, Timeout}, Timeout + 1000).

call(Procedure, Args, _Opts, Timeout) ->
    call(Procedure, Args, Timeout).

get_status() ->
    gen_server:call(?MODULE, get_status).

discover_subscribers(_Topic) ->
    {ok, []}.

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    %% The V2 `macula_client' pool we open in `activate/0' is
    %% linked (via `gen_server:start_link/3' inside
    %% `macula_client:connect/2'). Trap exits so a pool death does
    %% not cascade and we can self-heal in `handle_info/2'.
    erlang:process_flag(trap_exit, true),
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Bootstrap = case os:getenv("MACULA_RELAYS") of
        false -> application:get_env(hecate, bootstrap,
                     [<<"https://station-be-leuven-centrum.macula.io:4433">>]);
        EnvStr -> [list_to_binary(string:trim(U))
                   || U <- string:split(EnvStr, ",", all),
                      string:trim(U) =/= ""]
    end,
    Relays = [ensure_binary(R) || R <- Bootstrap],

    Cookie = atom_to_binary(erlang:get_cookie()),
    SiteId = binary:part(binary:encode_hex(crypto:hash(sha256, Cookie)), 0, 16),
    Site = maps:from_list([{K, V} || {K, V} <- [
        {site_id, SiteId},
        {name, env_bin("HECATE_SITE_NAME", SiteId)},
        {city, env_bin("HECATE_GEO_CITY", undefined)},
        {country, env_bin("HECATE_GEO_COUNTRY", undefined)},
        {lat, env_float("HECATE_GEO_LAT")},
        {lng, env_float("HECATE_GEO_LNG")},
        {site_type, env_bin("HECATE_SITE_TYPE", <<"daemon">>)}
    ], V =/= undefined]),

    Connections = case os:getenv("MACULA_CONNECTIONS") of
        false -> application:get_env(hecate, mesh_connections, 2);
        ConnStr ->
            try list_to_integer(string:trim(ConnStr))
            catch error:badarg -> 2
            end
    end,

    logger:info("[hecate_mesh] Ready in local mode (activate to connect, ~b relays configured)",
                [length(Relays)]),

    %% Join pg group for cluster-inherited realm credentials.
    %% When another node in the cluster joins a realm, it broadcasts here.
    %% Boot-order race: hecate_mesh_client:init/1 can run before the pg
    %% scope is up. If pg isn't available yet, schedule a retry instead
    %% of silently giving up — the scope comes up within a second or two
    %% during normal boot.
    ensure_pg_membership(),

    %% Boot mode: join_with_token takes priority over auto_activate.
    %% They are mutually exclusive — join_with_token implies activation.
    JoinToken = os:getenv("HECATE_REALM_JOIN_TOKEN"),
    AutoActivate = os:getenv("HECATE_MESH_AUTO_ACTIVATE", "false") =:= "true",
    case {JoinToken, AutoActivate} of
        {T, _} when is_list(T), T =/= "" ->
            erlang:send_after(3000, self(), join_with_token);
        {_, true} ->
            erlang:send_after(2000, self(), auto_activate);
        _ ->
            %% Self-heal on restart: if a realm membership has already
            %% been confirmed locally (persisted in replicated
            %% realm_memberships_store), activate automatically. The
            %% confirmed-activate PM only re-fires on fresh events, so
            %% a mesh_client crash post-activation leaves the mesh off
            %% forever without this hook. Delay gives the store time to
            %% be queryable.
            erlang:send_after(5000, self(), reactivate_if_confirmed)
    end,

    %% Seed the lock-free activated flag + pool handle. is_activated/0
    %% and get_client/0 read these from persistent_term to avoid blocking
    %% on this gen_server's call queue during boot contention.
    persistent_term:put({?MODULE, activated}, false),
    persistent_term:put({?MODULE, pool}, undefined),

    {ok, #state{
        pool = undefined,
        activated = false,
        realm = Realm,
        relays = Relays,
        connections = Connections,
        site = Site,
        pending_subs = [],
        pending_advs = []
    }}.

%% -- Activate ---------------------------------------------------------

handle_call(activate, _From, #state{activated = true} = State) ->
    {reply, {error, already_activated}, State};

handle_call(activate, _From, #state{activated = false} = State) ->
    #state{relays = Relays, realm = Realm,
           pending_subs = PendingSubs, pending_advs = PendingAdvs,
           pending_stream_advs = PendingStreamAdvs} = State,

    logger:info("[hecate_mesh] Activating mesh connection (~b relays, ~b pending subs, ~b pending advs, ~b pending stream advs)",
                [length(Relays), length(PendingSubs), length(PendingAdvs),
                 length(PendingStreamAdvs)]),

    %% V2 pool — covers pubsub, streaming RPC, non-stream RPC, and
    %% procedure advertisements. Identity is auto-generated; pubsub
    %% auth is per-payload, not per-link. dedup defaults (60s window)
    %% are fine for now.
    {ok, Pool} = macula:connect(Relays, #{}),

    %% Drain V2 subscriptions and stream advertisements as soon as
    %% the pool is up. Stream-advs replay automatically on link
    %% respawn so missed seats during boot self-heal.
    drain_pending_subs_v2(Pool, Realm, PendingSubs),
    drain_pending_stream_advs_v2(Pool, Realm, PendingStreamAdvs),

    %% Spin up the direct station-client pool for DHT ops only
    %% (the SDK facade does not yet expose put_record / find_record
    %% at the pool level).
    {StationClients, StationMonitors} = start_station_pool(Relays),
    logger:info("[hecate_mesh] Station-client pool: ~b alive (of ~b seeds)",
                [maps:size(StationClients), length(Relays)]),

    %% V2 unary advs cannot drain immediately — both the pool's
    %% station_links and the direct station-client pool return
    %% before CONNECT/HELLO completes, so a same-tick advertise
    %% would see no healthy links. Schedule a retry loop that
    %% re-attempts every second until each adv lands.
    erlang:send_after(0, self(), drain_pending_advs_v2),

    %% Run mesh proof ceremony (non-blocking)
    mesh_proof_coordinator:run_probes(),

    persistent_term:put({?MODULE, activated}, true),
    persistent_term:put({?MODULE, pool}, Pool),
    logger:info("[hecate_mesh] Mesh activated"),
    {reply, ok, State#state{pool = Pool, activated = true,
                            station_clients = StationClients,
                            station_monitors = StationMonitors,
                            pending_subs = [],
                            pending_stream_advs = []}};

%% -- Status ------------------------------------------------------------

handle_call(is_activated, _From, #state{activated = A} = State) ->
    {reply, A, State};

handle_call(get_status, _From,
            #state{pool = Pool, realm = Realm, relays = Relays,
                   station_clients = StationClients,
                   activated = Activated} = State) ->
    %% `macula:status/1' returns `self_node_id' as a raw 32-byte
    %% Ed25519 pubkey — not valid UTF-8, so `json:encode' chokes
    %% ({invalid_byte,_}) when this map reaches mesh_status_api /
    %% mesh_events_stream_api. Hex it here at the boundary.
    PoolStatus = hexify_node_id(get_pool_status(Pool)),
    StationLinks = station_links_view(StationClients),
    Status = #{
        connected => is_pid(Pool),
        activated => Activated,
        realm => Realm,
        %% The daemon's real identity, not a config string — reflects
        %% the current MRI (anonymous, or the realm-asserted owner).
        identity => hecate_identity:agent_id(),
        node_id => maps:get(self_node_id, PoolStatus, undefined),
        relays => Relays,
        pool => PoolStatus,
        station_links => StationLinks
    },
    {reply, {ok, Status}, State};

%% -- Mesh operations (forward to V2 pool if activated) -----------------

handle_call({publish, _Topic, _Payload}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({publish, Topic, Payload}, _From,
            #state{pool = Pool, realm = Realm} = State) ->
    %% V2 publish. The PUBLISH frame hits ONE station link
    %% (`macula:publish/4' = `replication_factor' = 1, SDK default).
    %% That station relays cross-station via publisher-end-to-end
    %% signed EVENT envelopes + (publisher, seq) dedup (macula-station
    %% Phase 2, cutover 2026-05-13), so a subscriber on any other
    %% station receives the event by multi-hop ADVERTISE/SUBSCRIBE
    %% propagation rather than depending on the publisher's daemon
    %% having dialed that station directly.
    %%
    %% (A `replication_factor => 99' fan-to-all-links stopgap lived
    %% here from the Phase-2 design window until the ETS-bypass
    %% router fix landed — see macula-station commit d0f0c8a, which
    %% collapsed cross-station ADVERTISE/SUBSCRIBE propagation
    %% latency to QUIC RTT. The stopgap caused each subscriber to
    %% receive the event once per shared station and is no longer
    %% needed.)
    %%
    %% Wrap with safe_mesh_call: the pool pid can be dead-but-still-
    %% referenced in the brief window between an EXIT message arriving
    %% and the EXIT handler running.
    PublishResult = safe_mesh_call(
          fun() ->
              macula:publish(Pool, macula_realm:id(Realm), Topic, Payload)
          end),
    case PublishResult of
        ok ->
            ok;
        _NotOk ->
            logger:warning("[hecate_mesh] macula:publish topic=~s result=~p",
                           [Topic, PublishResult])
    end,
    {reply, ok, State};

%% -- DHT record operations (PLAN_DHT_FIRST.md) -----------------------
%%
%% Routed through the station-client pool. Spawned off so the
%% gen_server keeps serving other calls while peering completes;
%% the worker replies to the caller via gen_server:reply/2.

handle_call(connected_peer_pubkeys, _From,
            #state{station_clients = Pool} = State) ->
    Pubkeys =
        [PK
         || P <- maps:values(Pool),
            is_pid(P), is_process_alive(P),
            {ok, PK} <- [safe_peer_node_id(P)]],
    {reply, Pubkeys, State};
handle_call({put_record, _R}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({put_record, Record}, From, #state{station_clients = Pool} = State) ->
    spawn(fun() ->
        gen_server:reply(From,
            dht_via_stations(maps:values(Pool),
                fun(P) -> macula_station_link:put_record(P, Record,
                                                           ?STATION_DHT_TIMEOUT_MS) end))
    end),
    {noreply, State};

handle_call({find_record, _Key}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({find_record, Key}, From, #state{station_clients = Pool} = State) ->
    spawn(fun() ->
        gen_server:reply(From,
            dht_via_stations(maps:values(Pool),
                fun(P) -> macula_station_link:find_record(P, Key,
                                                            ?STATION_DHT_TIMEOUT_MS) end))
    end),
    {noreply, State};

handle_call({find_records_by_type, _Type}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({find_records_by_type, Type}, From, #state{station_clients = Pool} = State) ->
    spawn(fun() ->
        gen_server:reply(From,
            dht_via_stations(maps:values(Pool),
                fun(P) ->
                    case macula_station_link:find_records_by_type(P, Type,
                                                                    ?STATION_DHT_TIMEOUT_MS) of
                        {ok, Records} -> {ok, Records};
                        Other -> Other
                    end
                end))
    end),
    {noreply, State};

handle_call({subscribe, Topic, Callback}, _From, #state{activated = false} = State) ->
    %% Queue it — will be applied on activate
    NewSubs = [{Topic, Callback} | State#state.pending_subs],
    {reply, {ok, queued}, State#state{pending_subs = NewSubs}};
handle_call({subscribe, Topic, Callback}, _From,
            #state{pool = Pool, realm = Realm} = State) ->
    Result = safe_mesh_call(fun() ->
        macula:subscribe_callback(Pool, macula_realm:id(Realm), Topic,
                                   wrap_v1_callback(Callback))
    end),
    {reply, Result, State};

handle_call({unsubscribe, _SubRef}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({unsubscribe, SubRef}, _From, #state{pool = Pool} = State) ->
    Result = safe_mesh_call(fun() -> macula:unsubscribe(Pool, SubRef) end),
    {reply, Result, State};

handle_call({advertise, Procedure, Handler}, _From, State) ->
    %% Always queue + kick the drain loop. If stations are connected,
    %% the retry tick (scheduled at zero delay) lands the adv this
    %% tick. If not, the loop keeps retrying until they handshake.
    NewAdvs = [{Procedure, Handler} | State#state.pending_advs],
    erlang:send_after(0, self(), drain_pending_advs_v2),
    {reply, {ok, queued}, State#state{pending_advs = NewAdvs}};

handle_call({rpc_call, _Procedure, _Args, _Timeout}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({rpc_call, Procedure, Args, Timeout}, From,
            #state{station_clients = Pool, realm = Realm} = State) ->
    %% Async: don't block the gen_server mailbox for the full RPC
    %% timeout (often 30s), which starves every other caller
    %% (subscribes, publishes, status checks). Spawn a worker, reply
    %% via gen_server:reply/2 when it returns.
    spawn(fun() ->
        gen_server:reply(From,
            call_via_any_station(maps:values(Pool), Realm, Procedure, Args, Timeout))
    end),
    {noreply, State};

handle_call({call_stream, _Procedure, _Args, _Timeout}, _From,
            #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({call_stream, Procedure, Args, Timeout}, From,
            #state{pool = Pool, realm = Realm} = State) ->
    %% Same async treatment as rpc_call — stream opens can block for
    %% the full Timeout while the remote handshake completes.
    %% Sticky-to-link: the returned stream pid is bound to the link
    %% the pool picked; if that link dies the stream errors with
    %% `peer_down' and the caller re-opens.
    spawn(fun() ->
        Result = safe_mesh_call(fun() ->
            macula:call_stream(Pool, macula_realm:id(Realm),
                               Procedure, Args,
                               #{owner => self(), deadline_ms => Timeout})
        end),
        gen_server:reply(From, Result)
    end),
    {noreply, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

%% -- Registration (cast, never blocks) ---------------------------------

handle_cast({register_sub, Topic, Callback}, #state{activated = false} = State) ->
    {noreply, State#state{pending_subs = [{Topic, Callback} | State#state.pending_subs]}};
handle_cast({register_sub, Topic, Callback},
            #state{pool = Pool, realm = Realm} = State) ->
    spawn(fun() ->
        macula:subscribe_callback(Pool, macula_realm:id(Realm), Topic,
                                   wrap_v1_callback(Callback))
    end),
    {noreply, State};

handle_cast({register_adv, Procedure, Handler}, State) ->
    %% Same path as the call form: queue + nudge the drain loop.
    NewAdvs = [{Procedure, Handler} | State#state.pending_advs],
    erlang:send_after(0, self(), drain_pending_advs_v2),
    {noreply, State#state{pending_advs = NewAdvs}};

handle_cast({register_stream_adv, Procedure, Mode, Handler},
            #state{activated = false} = State) ->
    Pending = [{Procedure, Mode, Handler} | State#state.pending_stream_advs],
    {noreply, State#state{pending_stream_advs = Pending}};
handle_cast({register_stream_adv, Procedure, Mode, Handler},
            #state{pool = Pool, realm = Realm} = State) ->
    spawn(fun() ->
        safe_mesh_call(fun() ->
            macula:advertise_stream(Pool, macula_realm:id(Realm),
                                    Procedure, Mode, Handler)
        end)
    end),
    {noreply, State};

handle_cast({unregister_adv, Procedure}, #state{activated = false} = State) ->
    %% Drop the pending entry if present; nothing else to do while dormant.
    Pending = [{P, H} || {P, H} <- State#state.pending_advs, P =/= Procedure],
    {noreply, State#state{pending_advs = Pending}};
handle_cast({unregister_adv, Procedure},
            #state{station_clients = Pool, realm = Realm} = State) ->
    spawn(fun() ->
        unadvertise_via_stations(maps:values(Pool), Realm, Procedure)
    end),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(auto_activate, #state{activated = false} = State) ->
    logger:info("[hecate_mesh] Auto-activating mesh (HECATE_MESH_AUTO_ACTIVATE=true)"),
    case handle_call(activate, {self(), make_ref()}, State) of
        {reply, ok, NewState} -> {noreply, NewState};
        {reply, _, NewState} -> {noreply, NewState}
    end;
handle_info(auto_activate, State) ->
    {noreply, State};

%% On boot / after a supervisor-restart, if the local store already
%% has a confirmed realm membership, activate automatically. The
%% confirmed-activate PM only re-fires on new events, so a crash
%% post-activation would otherwise leave the mesh dark. Silent no-op
%% if no credentials.
handle_info(reactivate_if_confirmed, #state{activated = true} = State) ->
    {noreply, State};
handle_info(reactivate_if_confirmed, #state{activated = false} = State) ->
    case has_confirmed_membership() of
        true ->
            logger:info("[hecate_mesh] Re-activating mesh for pre-existing realm membership"),
            case handle_call(activate, {self(), make_ref()}, State) of
                {reply, ok, NewState} -> {noreply, NewState};
                {reply, Other, NewState} ->
                    logger:warning("[hecate_mesh] Reactivate failed: ~p", [Other]),
                    %% Retry in a minute — relays might be transiently unreachable.
                    erlang:send_after(60000, self(), reactivate_if_confirmed),
                    {noreply, NewState}
            end;
        false ->
            {noreply, State}
    end;

%% Join realm via token — activate mesh first, then call join RPC
handle_info(join_with_token, #state{activated = false} = State) ->
    logger:info("[hecate_mesh] Join token set — activating mesh first"),
    case handle_call(activate, {self(), make_ref()}, State) of
        {reply, ok, NewState} ->
            erlang:send_after(2000, self(), do_join_with_token),
            {noreply, NewState};
        {reply, _, NewState} ->
            logger:warning("[hecate_mesh] Failed to activate for join token"),
            {noreply, NewState}
    end;
handle_info(join_with_token, State) ->
    %% Already activated — go straight to join
    erlang:send_after(1000, self(), do_join_with_token),
    {noreply, State};

handle_info(do_join_with_token,
            #state{station_clients = Pool} = State) when map_size(Pool) =:= 0 ->
    logger:warning("[hecate_mesh] No station_link pool yet — retrying join in 3s"),
    erlang:send_after(3000, self(), do_join_with_token),
    {noreply, State};
handle_info(do_join_with_token,
            #state{station_clients = Pool, realm = Realm} = State) ->
    Token = list_to_binary(os:getenv("HECATE_REALM_JOIN_TOKEN")),
    NodeName = hecate_identity:agent_id(),
    SiteId = case State#state.site of
        #{<<"site_id">> := Id} -> Id;
        _ -> undefined
    end,
    logger:info("[hecate_mesh] Joining realm with token ~s...",
                [binary:part(Token, 0, min(7, byte_size(Token)))]),
    Args = #{
        <<"token">> => Token,
        <<"node_name">> => NodeName,
        <<"site_id">> => SiteId
    },
    %% V2 path: macula-realm advertises `join_with_token_v1' on every
    %% relay it's connected to via `macula_station_link:advertise'.
    %% Any station in our pool routes the CALL to the realm via its
    %% per-conn remote-advertise registry. Procedure URI is the same
    %% string the realm registers (built via `realm_hope`).
    [LinkPid | _] = maps:values(Pool),
    RealmTag = macula_realm:id(Realm),
    spawn(fun() ->
        Procedure = hecate_topics:realm_hope(<<"membership">>, <<"join_with_token">>, 1),
        case catch macula_station_link:call(LinkPid, RealmTag, Procedure, Args, 10000) of
            {ok, Result} ->
                logger:info("[hecate_mesh] Realm join succeeded: ~p",
                            [maps:get(<<"realm_id">>, Result, <<"?">>)]),
                store_join_credentials(Result);
            {error, Reason} ->
                logger:error("[hecate_mesh] Realm join failed: ~p", [Reason]),
                erlang:send_after(5000, hecate_mesh_client, do_join_with_token);
            Other ->
                logger:error("[hecate_mesh] Realm join unexpected: ~p", [Other]),
                erlang:send_after(5000, hecate_mesh_client, do_join_with_token)
        end
    end),
    {noreply, State};

%% Cluster-inherited join: another node broadcast realm credentials
handle_info({realm_credentials, Credentials}, #state{activated = false} = State) ->
    RealmId = maps:get(realm_id, Credentials, maps:get(<<"realm_id">>, Credentials, <<"?">>)),
    logger:info("[hecate_mesh] Received realm credentials from cluster peer (realm=~s)", [RealmId]),
    %% Activate mesh with inherited credentials
    case handle_call(activate, {self(), make_ref()}, State) of
        {reply, ok, NewState} ->
            logger:info("[hecate_mesh] Mesh activated via cluster-inherited join"),
            {noreply, NewState};
        {reply, _, NewState} ->
            {noreply, NewState}
    end;
handle_info({realm_credentials, _Credentials}, State) ->
    %% Already activated — ignore
    {noreply, State};

handle_info(ensure_pg_membership, State) ->
    ensure_pg_membership(),
    {noreply, State};

%% V2 pool died (common on cross-station RPC timeouts to the realm
%% server). Don't die with it — drop the reference, mark inactive,
%% schedule a re-activate. Pending subs/advs are lost but the
%% call-sites re-register on demand.
handle_info({'EXIT', Pid, Reason},
            #state{pool = Pid, activated = true} = State) ->
    logger:warning("[hecate_mesh] V2 pool died (~p) — will reactivate", [Reason]),
    persistent_term:put({?MODULE, activated}, false),
    persistent_term:put({?MODULE, pool}, undefined),
    erlang:send_after(1500, self(), reactivate_if_confirmed),
    {noreply, State#state{pool = undefined,
                          activated = false,
                          pending_subs = [], pending_advs = [],
                          pending_stream_advs = []}};
%% Trap_exit catches exits from worker procs we spawn for rpc_call
%% and stream_call; those are normal completion signals, drop them.
handle_info({'EXIT', _Pid, _Reason}, State) ->
    {noreply, State};

%% A station-client in the pool died — respawn it after a short
%% backoff. Other pool members keep serving DHT calls in the meantime.
handle_info({'DOWN', Ref, process, _Pid, Reason},
            #state{station_clients = Pool, station_monitors = Mons} = State) ->
    case maps:take(Ref, Mons) of
        {Url, NewMons} ->
            logger:warning(
              "[hecate_mesh] Station-client for ~s died: ~p — respawning",
              [Url, Reason]),
            erlang:send_after(?STATION_RESPAWN_MS, self(), {respawn_station, Url}),
            {noreply, State#state{station_clients  = maps:remove(Url, Pool),
                                  station_monitors = NewMons}};
        error ->
            {noreply, State}
    end;

handle_info({respawn_station, Url}, #state{activated = false} = State) ->
    %% Mesh deactivated mid-respawn — drop the timer, the next activate
    %% rebuilds the whole pool.
    logger:debug("[hecate_mesh] Skip station respawn for ~s (mesh deactivated)", [Url]),
    {noreply, State};
handle_info(drain_pending_advs_v2, #state{activated = false} = State) ->
    {noreply, State};
handle_info(drain_pending_advs_v2,
            #state{station_clients = Pool, realm = Realm,
                   pending_advs = PendingAdvs} = State) ->
    %% Try each pending adv; keep the ones that fail so we can retry
    %% on the next tick. Successful advs get logged and dropped.
    Remaining = lists:filter(
        fun({Procedure, Handler}) ->
            attempt_keep_pending(advertise_via_stations(maps:values(Pool),
                                                        Realm, Procedure, Handler),
                                 Procedure)
        end, PendingAdvs),
    schedule_drain_advs_if_pending(Remaining),
    {noreply, State#state{pending_advs = Remaining}};

handle_info({respawn_station, Url}, #state{station_clients = Pool,
                                      station_monitors = Mons} = State) ->
    case start_station_client(Url) of
        {ok, Pid, Ref} ->
            logger:info("[hecate_mesh] Station-client respawned for ~s", [Url]),
            {noreply, State#state{station_clients  = Pool#{Url => Pid},
                                  station_monitors = Mons#{Ref => Url}}};
        {error, Reason} ->
            logger:warning(
              "[hecate_mesh] Station-client respawn for ~s failed: ~p — retry",
              [Url, Reason]),
            erlang:send_after(?STATION_RESPAWN_MS, self(), {respawn_station, Url}),
            {noreply, State}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

%% @private Join the pg scope if it's up; otherwise retry in a moment.
%% The boot order can put hecate_mesh_client:init/1 before the `pg`
%% scope is registered, so a one-shot join silently fails and the
%% client never receives cluster-inherited realm credentials.
ensure_pg_membership() ->
    case erlang:whereis(pg) of
        undefined ->
            erlang:send_after(500, self(), ensure_pg_membership),
            ok;
        _Pid ->
            try
                ok = pg:join(pg, hecate_realm_credentials, self()),
                logger:info("[hecate_mesh] joined pg group hecate_realm_credentials")
            catch Class:Reason ->
                logger:warning("[hecate_mesh] pg:join failed ~p:~p — retrying",
                               [Class, Reason]),
                erlang:send_after(500, self(), ensure_pg_membership)
            end
    end.

%% @private Broadcast realm credentials to all peers in the Erlang cluster.
%% Uses pg group — only hecate_mesh_client processes receive this.
broadcast_realm_credentials(Credentials) ->
    Members = try pg:get_members(pg, hecate_realm_credentials) catch exit:{noproc, _} -> [] end,
    Self = self(),
    Peers = [P || P <- Members, P =/= Self],
    case Peers of
        [] -> ok;
        _ ->
            logger:info("[hecate_mesh] Broadcasting realm credentials to ~b cluster peer(s)", [length(Peers)]),
            lists:foreach(fun(Pid) -> Pid ! {realm_credentials, Credentials} end, Peers)
    end.

%% @private Store credentials from join_with_token RPC response.
%% Dispatches confirm_realm_membership command which triggers the
%% on_realm_membership_confirmed_activate_mesh process manager.
store_join_credentials(Result) ->
    RealmId = maps:get(<<"realm_id">>, Result, <<"io.macula">>),
    ApiKey = maps:get(<<"api_key">>, Result, <<>>),
    NodeName = maps:get(<<"node_name">>, Result, <<"anonymous">>),
    MembershipId = <<"jt-", (base64:encode(crypto:strong_rand_bytes(12)))/binary>>,
    Cmd = confirm_realm_membership_v1:new(
        MembershipId, RealmId, NodeName, <<"join_token">>,
        erlang:system_time(second)
    ),
    Opts = #{
        store_id => realm_memberships_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },
    case evoq_dispatcher:dispatch(Cmd, Opts) of
        ok ->
            logger:info("[hecate_mesh] Realm membership confirmed via join token"),
            %% Store API key in application env (not os:putenv — that's visible in /proc)
            application:set_env(hecate, realm_api_key, ApiKey),
            %% Broadcast realm_id only — each peer gets its own key via token
            broadcast_realm_credentials(#{realm_id => RealmId});
        {error, Reason} ->
            logger:error("[hecate_mesh] Failed to store realm membership: ~p", [Reason])
    end.

terminate(_Reason, #state{pool = Pool}) ->
    persistent_term:put({?MODULE, pool}, undefined),
    catch close_pool(Pool),
    ok.

%%====================================================================
%% Internal
%%====================================================================

drain_pending_subs_v2(Pool, Realm, Subs) ->
    RealmTag = macula_realm:id(Realm),
    lists:foreach(fun({Topic, Callback}) ->
        case macula:subscribe_callback(Pool, RealmTag, Topic, wrap_v1_callback(Callback)) of
            {ok, _} -> logger:info("[hecate_mesh] Subscribed (v2): ~s", [Topic]);
            {error, R} -> logger:warning("[hecate_mesh] Subscribe ~s failed: ~p", [Topic, R])
        end
    end, Subs).

drain_pending_stream_advs_v2(Pool, Realm, StreamAdvs) ->
    RealmTag = macula_realm:id(Realm),
    lists:foreach(fun({Procedure, Mode, Handler}) ->
        case safe_mesh_call(fun() ->
            macula:advertise_stream(Pool, RealmTag, Procedure, Mode, Handler)
        end) of
            ok ->
                logger:info("[hecate_mesh] Stream-advertised (v2): ~s (mode=~p)",
                            [Procedure, Mode]);
            {error, R} ->
                logger:warning("[hecate_mesh] Stream-advertise ~s failed: ~p",
                               [Procedure, R])
        end
    end, StreamAdvs).

%% V1 pubsub callbacks were 1-arg `fun((Payload) -> any())'. V2's
%% `macula:subscribe_callback/4' expects 3-arg `fun((Topic, Payload,
%% Meta) -> any())'. Wrap at the boundary so existing call sites keep
%% their 1-arg shape; future cleanup can update them to consume Topic
%% / Meta directly.
wrap_v1_callback(Callback) when is_function(Callback, 1) ->
    fun(_Topic, Payload, _Meta) -> Callback(Payload) end;
wrap_v1_callback(Callback) when is_function(Callback, 3) ->
    %% Already V2-shape — pass through.
    Callback.

close_pool(undefined) -> ok;
close_pool(Pool) when is_pid(Pool) ->
    macula:close(Pool).

%% Per-adv result handler for the periodic V2 drain. `true' means keep
%% the adv on pending_advs and retry next tick; `false' means it
%% landed and we drop it.
attempt_keep_pending(ok, Procedure) ->
    logger:info("[hecate_mesh] Advertised (v2): ~s", [Procedure]),
    false;
attempt_keep_pending({error, no_station_connected}, _Procedure) ->
    %% Stations still handshaking — silent, will retry.
    true;
attempt_keep_pending({error, Reason}, Procedure) ->
    logger:warning("[hecate_mesh] Advertise (v2) ~s failed: ~p — retrying",
                   [Procedure, Reason]),
    true.

schedule_drain_advs_if_pending([]) ->
    ok;
schedule_drain_advs_if_pending(_Pending) ->
    erlang:send_after(1000, self(), drain_pending_advs_v2),
    ok.

%%--------------------------------------------------------------------
%% V2 RPC fan-out helpers.
%%
%% advertise_via_stations / unadvertise_via_stations: register the
%% handler on every CURRENTLY-CONNECTED station_link in the pool so
%% any peer-routed CALL reaches us regardless of which station
%% carried it. Returns ok if at least one station accepted; aggregate
%% failures are logged but not fatal.
%%
%% call_via_any_station: try each connected link in turn, return the
%% first non-error response. Mirrors `dht_via_stations/2' for the RPC
%% surface.
%%--------------------------------------------------------------------

advertise_via_stations(LinkPids, Realm, Procedure, Handler) ->
    fan_out(connected_only(LinkPids),
            fun(P) -> macula_station_link:advertise(P,
                                                     macula_realm:id(Realm),
                                                     Procedure,
                                                     Handler) end,
            advertise).

unadvertise_via_stations(LinkPids, Realm, Procedure) ->
    fan_out(connected_only(LinkPids),
            fun(P) -> macula_station_link:unadvertise(P,
                                                       macula_realm:id(Realm),
                                                       Procedure) end,
            unadvertise).

call_via_any_station([], _Realm, _Procedure, _Args, _Timeout) ->
    {error, no_station_connected};
call_via_any_station([Pid | Rest], Realm, Procedure, Args, Timeout) ->
    case macula_station_link:is_connected(Pid) of
        false when Rest =:= [] -> {error, not_connected};
        false                  -> call_via_any_station(Rest, Realm, Procedure, Args, Timeout);
        true                   -> try_call_then_next(
                                    macula_station_link:call(Pid,
                                                              macula_realm:id(Realm),
                                                              Procedure,
                                                              Args,
                                                              Timeout),
                                    Rest, Realm, Procedure, Args, Timeout)
    end.

try_call_then_next({ok, _} = R, _Rest, _Realm, _Procedure, _Args, _Timeout) -> R;
try_call_then_next({error, _} = E, [], _Realm, _Procedure, _Args, _Timeout) -> E;
try_call_then_next({error, _Reason}, Rest, Realm, Procedure, Args, Timeout) ->
    call_via_any_station(Rest, Realm, Procedure, Args, Timeout).

connected_only(LinkPids) ->
    [P || P <- LinkPids,
          is_pid(P), is_process_alive(P),
          macula_station_link:is_connected(P)].

fan_out([], _Op, _Tag) ->
    {error, no_station_connected};
fan_out(Pids, Op, _Tag) ->
    Results = [Op(P) || P <- Pids],
    case lists:any(fun (ok) -> true; ({ok, _}) -> true; (_) -> false end, Results) of
        true  -> ok;
        false -> {error, all_stations_failed}
    end.

safe_mesh_call(Fun) ->
    try Fun()
    catch
        exit:{timeout, _} -> {error, mesh_timeout};
        exit:{noproc, _} -> {error, mesh_not_started};
        exit:{{timeout, _}, _} -> {error, mesh_timeout}
    end.

%% gen_server:call wrapper for the DHT record API. The handle_call
%% spawns a worker that replies asynchronously after up to
%% STATION_DHT_TIMEOUT_MS. The caller's gen_server:call timeout
%% must exceed that or the caller exits with {timeout, _} before
%% the worker has a chance to send `{error, timeout}'. Catch the
%% race here and surface it as `{error, timeout}'.
%% @doc Pubkeys of currently-connected station_link peers. Used by
%% the announce path to set `station_id' on each daemon presence
%% record so the realm topology can render daemons attached to
%% their parent relay (V1 parity).
-spec connected_peer_pubkeys() -> [macula_identity:pubkey()].
connected_peer_pubkeys() ->
    case safe_call(connected_peer_pubkeys, 1_000) of
        L when is_list(L) -> L;
        _                 -> []
    end.

safe_peer_node_id(LinkPid) ->
    try macula_station_link:peer_node_id(LinkPid)
    catch _:_ -> {error, exception}
    end.

safe_call(Msg, Timeout) ->
    try gen_server:call(?MODULE, Msg, Timeout)
    catch
        exit:{timeout, _}      -> {error, timeout};
        exit:{noproc, _}       -> {error, not_started};
        exit:{{timeout, _}, _} -> {error, timeout}
    end.

%% Reply shaping for the DHT record RPC handlers.
%%--------------------------------------------------------------------
%% Station-client pool helpers
%%--------------------------------------------------------------------

%% Spin up one station-client per relay seed. Returns the maps
%% {Url => Pid} and {MonitorRef => Url}. Failed seeds get a delayed
%% respawn message so the pool eventually reaches full size.
start_station_pool(Relays) ->
    lists:foldl(fun(Url, {Clients, Mons}) ->
        case start_station_client(Url) of
            {ok, Pid, Ref} ->
                {Clients#{Url => Pid}, Mons#{Ref => Url}};
            {error, Reason} ->
                logger:warning(
                  "[hecate_mesh] Station-client init for ~s failed: ~p — retry",
                  [Url, Reason]),
                erlang:send_after(?STATION_RESPAWN_MS, self(), {respawn_station, Url}),
                {Clients, Mons}
        end
    end, {#{}, #{}}, Relays).

start_station_client(Url) ->
    case macula_station_link:start_link(#{seed => Url}) of
        {ok, Pid} ->
            Ref = erlang:monitor(process, Pid),
            {ok, Pid, Ref};
        {error, _Reason} = E ->
            E
    end.

%% Try the operation against each station-client in turn. Succeed on
%% the first connected client that returns ok / {ok, _}; on disconnected
%% / timeout / error, fall through to the next. Empty pool returns
%% {error, no_station_connected}.
dht_via_stations([], _Op) ->
    {error, no_station_connected};
dht_via_stations([Pid | Rest], Op) ->
    case macula_station_link:is_connected(Pid) of
        true ->
            try_next_station(Op(Pid), Rest, Op);
        false when Rest =:= [] ->
            {error, not_connected};
        false ->
            dht_via_stations(Rest, Op)
    end.

try_next_station(ok, _Rest, _Op)        -> ok;
try_next_station({ok, _} = R, _Rest, _Op) -> R;
try_next_station({error, _} = E, [], _Op) -> E;
try_next_station({error, _Reason}, Rest, Op) ->
    %% Fall through to next pool member on per-call failure.
    dht_via_stations(Rest, Op).

%% DHT operations route through macula_station_link which handles
%% its own result classification.

get_pool_status(undefined) -> #{};
get_pool_status(Pool) when is_pid(Pool) ->
    case safe_mesh_call(fun() -> macula:status(Pool) end) of
        {ok, S} -> S;
        _ -> #{}
    end.

%% Render the raw-binary `self_node_id' field (if any) as hex so the
%% status map is JSON-encodable.
hexify_node_id(#{self_node_id := B} = S) when is_binary(B) ->
    S#{self_node_id => binary:encode_hex(B)};
hexify_node_id(S) ->
    S.

station_links_view(StationClients) ->
    [#{relay     => Url,
       alive     => is_pid(Pid) andalso is_process_alive(Pid),
       connected => safe_is_connected(Pid)}
     || {Url, Pid} <- maps:to_list(StationClients)].

safe_is_connected(Pid) when is_pid(Pid) ->
    try macula_station_link:is_connected(Pid)
    catch _:_ -> false
    end;
safe_is_connected(_) -> false.

%% @private Does the event store show ANY realm membership activity
%% that hasn't been explicitly ended? Used by reactivate_if_confirmed
%% to decide whether the mesh should come up automatically on boot.
%%
%% Intentionally reads the event store directly rather than the ETS
%% projection: ETS-backed projections are wiped on restart while evoq's
%% subscription checkpoint persists, so the projection can be stale-empty
%% after a restart even when the store has events.
%%
%% Also intentionally permissive about event type: a stream that has
%% only `realm_membership_initiated_v1` (no confirmed_v1 persisted —
%% an observed failure mode when the confirm dispatch trips a
%% wrong_expected_version in Ra) still counts as an intent to be on
%% the mesh. Mesh activation is topological (connect to relays) and
%% doesn't require a cert to be present; the per-node cert matters
%% for realm-authenticated RPCs only.
has_confirmed_membership() ->
    try
        case evoq_event_store:read_all_global(realm_memberships_store, 0, 1000) of
            {ok, Events} -> any_live_membership(Events);
            _ -> false
        end
    catch
        _:_ -> false
    end.

any_live_membership(Events) ->
    Status = lists:foldl(fun(E, Acc) ->
        Type = event_type(E),
        MId  = membership_id(event_data(E)),
        case {Type, MId} of
            {_, undefined}                                 -> Acc;
            {<<"realm_membership_initiated_v1">>, MembId}  -> maps:put(MembId, live, Acc);
            {<<"realm_membership_confirmed_v1">>, MembId}  -> maps:put(MembId, live, Acc);
            {<<"realm_credentials_secured_v1">>,  MembId}  -> maps:put(MembId, live, Acc);
            {<<"realm_membership_ended_v1">>,     MembId}  -> maps:put(MembId, ended, Acc);
            {<<"realm_membership_resigned_v1">>,  MembId}  -> maps:put(MembId, ended, Acc);
            {<<"realm_membership_revoked_v1">>,   MembId}  -> maps:put(MembId, ended, Acc);
            _                                               -> Acc
        end
    end, #{}, Events),
    lists:any(fun(S) -> S =:= live end, maps:values(Status)).

membership_id(#{membership_id := Id})        -> Id;
membership_id(#{<<"membership_id">> := Id})  -> Id;
membership_id(_)                             -> undefined.

event_type(#{event_type := T})         -> T;
event_type(#{<<"event_type">> := T})   -> T;
event_type({evoq_event, _EventId, T, _StreamId, _Version, _Data, _Metadata,
            _Tags, _Timestamp, _Epoch, _DataCT, _MetaCT}) -> T;
event_type(_) -> undefined.

%% evoq_event records carry Data as element 6 (1-indexed) — 6th after
%% the record tag. maps:get on a record raises badmap, which the
%% try/catch in has_confirmed_membership silently swallows, making
%% every event look like it has no membership_id.
event_data(#{data := D})                                -> D;
event_data(#{<<"data">> := D})                          -> D;
event_data({evoq_event, _EventId, _Type, _StreamId, _Version, D, _Metadata,
            _Tags, _Timestamp, _Epoch, _DataCT, _MetaCT}) -> D;
event_data(_) -> #{}.

ensure_binary(B) when is_binary(B) -> B;
ensure_binary(S) when is_list(S) -> list_to_binary(S).

env_bin(Key, Default) ->
    case os:getenv(Key) of
        false -> Default;
        "" -> Default;
        Val -> list_to_binary(Val)
    end.

env_float(Key) ->
    case os:getenv(Key) of
        false -> undefined;
        "" -> undefined;
        Val -> parse_float_safe(Val)
    end.

parse_float_safe(Val) ->
    case string:to_float(Val) of
        {F, []} -> F;
        _ ->
            case string:to_integer(Val) of
                {I, []} -> float(I);
                _ -> undefined
            end
    end.
