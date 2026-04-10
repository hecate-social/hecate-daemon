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
-export([register_subscription/2, register_advertisement/2]).
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
    pending_advs :: [{binary(), fun()}]
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

    %% Headless nodes (no web UI) can auto-activate mesh on boot
    AutoActivate = os:getenv("HECATE_MESH_AUTO_ACTIVATE", "false") =:= "true",
    case AutoActivate of
        true -> erlang:send_after(2000, self(), auto_activate);
        false -> ok
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
           pending_subs = PendingSubs, pending_advs = PendingAdvs} = State,

    logger:info("[hecate_mesh] Activating mesh connection (~b relays, ~b pending subs, ~b pending advs)",
                [length(Relays), length(PendingSubs), length(PendingAdvs)]),

    {ok, Client} = macula_multi_relay:start_link(#{
        relays => Relays,
        realm => Realm,
        identity => Identity,
        site => Site,
        connections => Connections
    }),

    %% Drain pending registrations (best-effort, don't crash on failure)
    drain_pending(Client, PendingSubs, PendingAdvs),

    %% Run mesh proof ceremony (non-blocking)
    mesh_proof_coordinator:run_probes(),

    logger:info("[hecate_mesh] Mesh activated"),
    {reply, ok, State#state{client = Client, activated = true,
                            pending_subs = [], pending_advs = []}};

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
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{client = Client}) ->
    catch macula_multi_relay:stop(Client),
    ok.

%%====================================================================
%% Internal
%%====================================================================

drain_pending(Client, Subs, Advs) ->
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
    end, Advs).

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
