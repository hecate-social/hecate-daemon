%%%-------------------------------------------------------------------
%%% @doc Hecate mesh client — local-first, activate-on-demand.
%%%
%%% Starts in local mode (no network). Domain apps register
%%% subscriptions and advertisements immediately. Actual QUIC
%%% connections are established only when activate/0 is called
%%% (triggered by POST /api/mesh/activate from the web UI).
%%%
%%% On activation: starts macula_multi_relay, drains pending
%%% registrations, runs mesh proof ceremony.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_mesh_client).
-behaviour(gen_server).

-export([start_link/0, activate/0, is_activated/0]).
-export([get_client/0, get_status/0, publish/2, subscribe/2,
         unsubscribe/1, discover_subscribers/1, advertise/2, call/3, call/4]).
-export([register_subscription/2, register_advertisement/2,
         unregister_advertisement/1,
         register_stream_advertisement/3, call_stream/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    client :: pid() | undefined,        %% macula_multi_relay pid (nil until activated)
    activated :: boolean(),
    realm :: binary(),
    identity :: binary(),
    relays :: [binary()],
    connections :: pos_integer(),
    site :: map(),
    pending_subs :: [{binary(), fun()}],
    pending_advs :: [{binary(), fun()}],
    pending_stream_advs = [] :: [{binary(), atom(), fun()}]
}).

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
    gen_server:call(?MODULE, is_activated).

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

get_client() ->
    gen_server:call(?MODULE, get_client).

publish(Topic, Payload) ->
    gen_server:call(?MODULE, {publish, Topic, Payload}).

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
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Identity = application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>),
    Bootstrap = case os:getenv("MACULA_RELAYS") of
        false -> application:get_env(hecate, bootstrap,
                     [<<"https://relay00.macula.io:4433">>]);
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
        _ -> ok
    end,

    {ok, #state{
        client = undefined,
        activated = false,
        realm = Realm,
        identity = Identity,
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
    #state{relays = Relays, realm = Realm, identity = Identity,
           site = Site, connections = Connections,
           pending_subs = PendingSubs, pending_advs = PendingAdvs,
           pending_stream_advs = PendingStreamAdvs} = State,

    logger:info("[hecate_mesh] Activating mesh connection (~b relays, ~b pending subs, ~b pending advs, ~b pending stream advs)",
                [length(Relays), length(PendingSubs), length(PendingAdvs),
                 length(PendingStreamAdvs)]),

    {ok, Client} = macula_multi_relay:start_link(#{
        relays => Relays,
        realm => Realm,
        identity => Identity,
        site => Site,
        connections => Connections
    }),

    %% Drain pending registrations (best-effort, don't crash on failure)
    drain_pending(Client, PendingSubs, PendingAdvs, PendingStreamAdvs),

    %% Run mesh proof ceremony (non-blocking)
    mesh_proof_coordinator:run_probes(),

    logger:info("[hecate_mesh] Mesh activated"),
    {reply, ok, State#state{client = Client, activated = true,
                            pending_subs = [], pending_advs = [],
                            pending_stream_advs = []}};

%% -- Status ------------------------------------------------------------

handle_call(is_activated, _From, #state{activated = A} = State) ->
    {reply, A, State};

handle_call(get_client, _From, #state{client = Client} = State) ->
    {reply, {ok, Client}, State};

handle_call(get_status, _From, #state{client = Client, realm = Realm,
                                       identity = Identity, relays = Relays,
                                       connections = Connections,
                                       activated = Activated} = State) ->
    MultiStatus = get_multi_status(Client),
    Status = #{
        connected => is_pid(Client),
        activated => Activated,
        realm => Realm,
        identity => Identity,
        relays => Relays,
        connections => Connections,
        multi_relay => MultiStatus,
        mode => multi_relay
    },
    {reply, {ok, Status}, State};

%% -- Mesh operations (forward to multi_relay if activated) -------------

handle_call({publish, _Topic, _Payload}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({publish, Topic, Payload}, _From, #state{client = Client} = State) ->
    macula_multi_relay:publish(Client, Topic, Payload),
    {reply, ok, State};

handle_call({subscribe, Topic, Callback}, _From, #state{activated = false} = State) ->
    %% Queue it — will be applied on activate
    NewSubs = [{Topic, Callback} | State#state.pending_subs],
    {reply, {ok, queued}, State#state{pending_subs = NewSubs}};
handle_call({subscribe, Topic, Callback}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:subscribe(Client, Topic, Callback) end),
    {reply, Result, State};

handle_call({unsubscribe, _SubRef}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({unsubscribe, SubRef}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:unsubscribe(Client, SubRef) end),
    {reply, Result, State};

handle_call({advertise, Procedure, Handler}, _From, #state{activated = false} = State) ->
    NewAdvs = [{Procedure, Handler} | State#state.pending_advs],
    {reply, {ok, queued}, State#state{pending_advs = NewAdvs}};
handle_call({advertise, Procedure, Handler}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:advertise(Client, Procedure, Handler) end),
    {reply, Result, State};

handle_call({rpc_call, _Procedure, _Args, _Timeout}, _From, #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({rpc_call, Procedure, Args, Timeout}, _From, #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() -> macula_multi_relay:call(Client, Procedure, Args, Timeout) end),
    {reply, Result, State};

handle_call({call_stream, _Procedure, _Args, _Timeout}, _From,
            #state{activated = false} = State) ->
    {reply, {error, not_activated}, State};
handle_call({call_stream, Procedure, Args, Timeout}, _From,
            #state{client = Client} = State) ->
    Result = safe_mesh_call(fun() ->
        macula_multi_relay:call_stream(Client, Procedure, Args, Timeout)
    end),
    {reply, Result, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

%% -- Registration (cast, never blocks) ---------------------------------

handle_cast({register_sub, Topic, Callback}, #state{activated = false} = State) ->
    {noreply, State#state{pending_subs = [{Topic, Callback} | State#state.pending_subs]}};
handle_cast({register_sub, Topic, Callback}, #state{client = Client} = State) ->
    spawn(fun() -> safe_mesh_call(fun() -> macula_multi_relay:subscribe(Client, Topic, Callback) end) end),
    {noreply, State};

handle_cast({register_adv, Procedure, Handler}, #state{activated = false} = State) ->
    {noreply, State#state{pending_advs = [{Procedure, Handler} | State#state.pending_advs]}};
handle_cast({register_adv, Procedure, Handler}, #state{client = Client} = State) ->
    spawn(fun() -> safe_mesh_call(fun() -> macula_multi_relay:advertise(Client, Procedure, Handler) end) end),
    {noreply, State};

handle_cast({register_stream_adv, Procedure, Mode, Handler},
            #state{activated = false} = State) ->
    Pending = [{Procedure, Mode, Handler} | State#state.pending_stream_advs],
    {noreply, State#state{pending_stream_advs = Pending}};
handle_cast({register_stream_adv, Procedure, Mode, Handler},
            #state{client = Client} = State) ->
    spawn(fun() ->
        safe_mesh_call(fun() ->
            macula_multi_relay:advertise_stream(Client, Procedure, Mode, Handler)
        end)
    end),
    {noreply, State};

handle_cast({unregister_adv, Procedure}, #state{activated = false} = State) ->
    %% Drop the pending entry if present; nothing else to do while dormant.
    Pending = [{P, H} || {P, H} <- State#state.pending_advs, P =/= Procedure],
    {noreply, State#state{pending_advs = Pending}};
handle_cast({unregister_adv, Procedure}, #state{client = Client} = State) ->
    spawn(fun() -> safe_mesh_call(fun() -> macula_multi_relay:unadvertise(Client, Procedure) end) end),
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

handle_info(do_join_with_token, #state{client = undefined} = State) ->
    logger:warning("[hecate_mesh] No mesh client — retrying join in 3s"),
    erlang:send_after(3000, self(), do_join_with_token),
    {noreply, State};
handle_info(do_join_with_token, #state{client = Client} = State) ->
    Token = list_to_binary(os:getenv("HECATE_REALM_JOIN_TOKEN")),
    NodeName = State#state.identity,
    SiteId = case State#state.site of
        #{<<"site_id">> := Id} -> Id;
        _ -> undefined
    end,
    logger:info("[hecate_mesh] Joining realm with token ~s...", [binary:part(Token, 0, min(7, byte_size(Token)))]),
    Args = #{
        <<"token">> => Token,
        <<"node_name">> => NodeName,
        <<"site_id">> => SiteId
    },
    spawn(fun() ->
        Procedure = hecate_topics:realm_hope(<<"membership">>, <<"join_with_token">>, 1),
        case catch macula:call(Client, Procedure, Args, 10000) of
            {ok, Result} ->
                logger:info("[hecate_mesh] Realm join succeeded: ~p", [maps:get(<<"realm_id">>, Result, <<"?">>)]),
                store_join_credentials(Result);
            {error, Reason} ->
                logger:error("[hecate_mesh] Realm join failed: ~p", [Reason]);
            Other ->
                logger:error("[hecate_mesh] Realm join unexpected: ~p", [Other])
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

terminate(_Reason, #state{client = Client}) ->
    catch macula_multi_relay:stop(Client),
    ok.

%%====================================================================
%% Internal
%%====================================================================

drain_pending(Client, Subs, Advs, StreamAdvs) ->
    lists:foreach(fun({Topic, Callback}) ->
        case safe_mesh_call(fun() -> macula_multi_relay:subscribe(Client, Topic, Callback) end) of
            {ok, _} -> logger:info("[hecate_mesh] Subscribed: ~s", [Topic]);
            {error, R} -> logger:warning("[hecate_mesh] Subscribe ~s failed: ~p", [Topic, R])
        end
    end, Subs),
    lists:foreach(fun({Procedure, Handler}) ->
        case safe_mesh_call(fun() -> macula_multi_relay:advertise(Client, Procedure, Handler) end) of
            {ok, _} -> logger:info("[hecate_mesh] Advertised: ~s", [Procedure]);
            {error, R} -> logger:warning("[hecate_mesh] Advertise ~s failed: ~p", [Procedure, R])
        end
    end, Advs),
    lists:foreach(fun({Procedure, Mode, Handler}) ->
        case safe_mesh_call(fun() -> macula_multi_relay:advertise_stream(Client, Procedure, Mode, Handler) end) of
            ok -> logger:info("[hecate_mesh] Stream-advertised: ~s (mode=~p)", [Procedure, Mode]);
            {error, R} -> logger:warning("[hecate_mesh] Stream-advertise ~s failed: ~p", [Procedure, R])
        end
    end, StreamAdvs).

safe_mesh_call(Fun) ->
    try Fun()
    catch
        exit:{timeout, _} -> {error, mesh_timeout};
        exit:{noproc, _} -> {error, mesh_not_started};
        exit:{{timeout, _}, _} -> {error, mesh_timeout}
    end.

get_multi_status(Client) when is_pid(Client) ->
    case macula_multi_relay:get_status(Client) of
        {ok, MS} -> MS;
        _ -> #{}
    end;
get_multi_status(_) -> #{}.

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
