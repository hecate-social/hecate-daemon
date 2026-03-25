%%%-------------------------------------------------------------------
%%% @doc Hecate application module.
%%%
%%% Starts the Hecate agent sidecar daemon with non-blocking boot.
%%%
%%% Startup order:
%%% 1. Directory layout (ensure ~/.hecate/hecate-daemon/* exists)
%%% 2. hecate-agents repo (clone if missing, non-blocking on failure)
%%% 3. Lifecycle files (daemon.pid, daemon.state = starting)
%%% 4. Unix socket with minimal health-only dispatch (clients see ready:false)
%%% 5. ReckonDB (embedded event store infrastructure)
%%% 6. Evoq (CQRS framework)
%%% 7. hecate_sup (includes boot_tracker with telemetry handler)
%%% 8. Spawn store processes (fire-and-forget — boot_tracker listens)
%%% 9. return {ok, SupPid} — domain apps boot via release config
%%%
%%% The boot_tracker receives telemetry events as stores come up and
%%% triggers the post-boot sequence (subscriptions, routes, readiness)
%%% once all stores are ready (or a 60s timeout fires).
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_app).
-behaviour(application).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start/2, stop/1]).
-export([start_store_subscriptions/1]).

%% Store definitions: {StoreId, SubDir, Label}
%% Martha stores (martha_store, orchestration_store, knowledge_graph_store,
%% retry_strategy_store, cost_budget_store) moved to hecate-app-martha plugin.
-define(STORES, [
    {settings_store,            "settings",            "Settings (identity, preferences)"},
    {realm_memberships_store,   "realm_memberships",   "Realm Memberships (join, confirm, revoke)"},
    {llm_store,                 "llm",                 "LLM (detection, status reporting)"},
    {licenses_store,            "licenses",            "Licenses (consumer lifecycle)"},
    {license_offerings_store,   "license_offerings",   "License Offerings (author catalog)"},
    {procurements_store,        "procurements",        "Procurements (buying process)"},
    {sales_store,               "sales",               "Sales (selling process)"},
    {payments_store,            "payments",            "Payments (payment process)"},
    {plugins_store,             "plugins",             "Plugins (install/upgrade/remove)"},
    {launcher_store,            "launcher",            "Launcher (sidebar layout lifecycle)"},
    {mpong_store,               "mpong",               "MPong (mesh pong game lifecycle)"}
]).

%% Site store (cluster nodes, site-level state).
-define(SITE_STORES, [
    {site_store, "site", "Site (realm membership, cluster nodes)"}
]).

%%--------------------------------------------------------------------
%% @doc Start the Hecate application.
%% @end
%%--------------------------------------------------------------------
-spec start(StartType, StartArgs) -> {ok, Pid} | {error, Reason} when
    StartType :: application:start_type(),
    StartArgs :: term(),
    Pid :: pid(),
    Reason :: term().
start(_StartType, _StartArgs) ->
    logger:info("Starting Hecate"),

    %% Raise macula QUIC rate limits for LAN mesh clusters (default 5/IP is too low)
    application:set_env(macula, quic_max_conn_per_ip, 50),
    application:set_env(macula, quic_max_conn_global_per_sec, 200),

    %% 1. Create namespaced directory layout
    shared_paths:ensure_layout(),

    %% 2. Ensure hecate-agents repo is cloned (non-blocking on failure)
    case hecate_agents_repo:ensure() of
        {ok, AgentsPath} ->
            logger:info("hecate-agents available at ~s", [AgentsPath]);
        {error, _AgentsReason} ->
            logger:warning("hecate-agents not available — some features may be limited")
    end,

    %% 3. Write lifecycle files (daemon.pid + state = starting)
    hecate_lifecycle:init(),

    %% 4. Start socket with minimal health-only dispatch
    start_early_socket(),

    %% 5. Start ReckonDB infrastructure
    logger:info("Starting ReckonDB infrastructure..."),
    case application:ensure_all_started(reckon_db) of
        {ok, _ReckonApps} ->
            logger:info("ReckonDB infrastructure ready"),
            start_evoq();
        {error, ReckonReason} ->
            logger:error("Failed to start ReckonDB: ~p", [ReckonReason]),
            {error, {reckon_db_start_failed, ReckonReason}}
    end.

%% @private Start the Unix socket with a minimal startup-health-only dispatch.
%% This makes the socket available immediately so clients can poll health
%% and see ready:false while domain apps are still booting.
start_early_socket() ->
    case hecate_socket:get_socket_path() of
        undefined ->
            logger:info("Socket path is undefined, skipping early socket");
        Path ->
            StartupDispatch = cowboy_router:compile([
                {'_', [
                    {"/health", hecate_api_startup_health, []},
                    {"/api/events", web_events_stream_api, []},
                    {"/api/health", hecate_api_startup_health, []}
                ]}
            ]),
            case hecate_socket:start_listener(Path, StartupDispatch) of
                ok ->
                    logger:info("Early socket ready (health-only)");
                {error, Reason} ->
                    logger:warning("Early socket failed: ~p", [Reason])
            end
    end.

%% @private Start Evoq (CQRS framework), then supervisor, then spawn stores.
start_evoq() ->
    logger:info("Starting Evoq (CQRS framework)..."),
    case application:ensure_all_started(evoq) of
        {ok, _EvoqApps} ->
            logger:info("Evoq started successfully"),
            start_supervisor_then_stores();
        {error, EvoqReason} ->
            logger:error("Failed to start Evoq: ~p", [EvoqReason]),
            {error, {evoq_start_failed, EvoqReason}}
    end.

%% @private Start supervisor FIRST (so boot_tracker's telemetry handler is
%% registered), then spawn store processes fire-and-forget.
start_supervisor_then_stores() ->
    AllStores = ?STORES ++ ?SITE_STORES,
    StoreIds = [Id || {Id, _, _} <- AllStores],
    logger:info("Starting Hecate supervisor..."),
    case hecate_sup:start_link(StoreIds) of
        {ok, SupPid} ->
            %% Self-instrument daemon stores for /metrics
            hecate_plugin_metrics:init(<<"hecate">>),
            lists:foreach(fun({StoreId, _, _}) ->
                hecate_plugin_telemetry:attach(<<"hecate">>, StoreId)
            end, AllStores),

            %% Supervisor (and boot_tracker) are up — safe to spawn stores
            spawn_stores(?STORES ++ ?SITE_STORES),
            {ok, SupPid};
        {error, _} = Error ->
            Error
    end.

%% @private Spawn a process per store (fire-and-forget).
%% Uses spawn (NOT spawn_link) — a store crash shouldn't take down the
%% app controller. Boot tracker handles failures via timeout.
spawn_stores(Stores) ->
    %% Start stores in single mode for fast boot. Cluster join happens
    %% later in boot_tracker:maybe_join_cluster/1 after readiness.
    Mode = application:get_env(hecate, store_mode, single),
    logger:info("Spawning ~b event store processes (mode=~p)...", [length(Stores), Mode]),
    %% Start stores sequentially to avoid overwhelming Khepri/Ra.
    %% Each store creates its own Ra system — parallel starts cause
    %% file lock contention and resource exhaustion.
    spawn(fun() -> start_stores_sequential(Stores, Mode) end).

start_stores_sequential([], _Mode) ->
    logger:info("All event stores spawned"),
    ok;
start_stores_sequential([{StoreId, SubDir, Label} | Rest], Mode) ->
    logger:info("Starting ~s event store (~p, mode=~p)...", [Label, StoreId, Mode]),
    DataDir = shared_paths:reckon_path(SubDir),
    ok = filelib:ensure_path(DataDir),
    Config = #store_config{
        store_id = StoreId,
        data_dir = DataDir,
        mode = Mode,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 2,
        options = #{}
    },
    %% Fire-and-forget: start each store in its own unlinked process.
    %% Boot tracker polls reckon_db_sup:which_stores() to detect readiness.
    %% Do NOT kill slow stores — let them finish in the background.
    spawn(fun() ->
        try start_store(Config)
        catch Class:Reason:Stack ->
            logger:error("Store ~p crashed: ~p:~p~n~p",
                         [StoreId, Class, Reason, Stack])
        end
    end),
    %% Small delay between spawns to reduce I/O contention on slow disks
    timer:sleep(500),
    start_stores_sequential(Rest, Mode).



%% @private Start a single ReckonDB store, handling already_started.
start_store(#store_config{store_id = StoreId} = Config) ->
    case reckon_db_sup:start_store(Config) of
        {ok, _Pid} ->
            logger:info("Event store ~p ready", [StoreId]),
            ok;
        {error, {already_started, _Pid}} ->
            logger:info("Event store ~p already running", [StoreId]),
            ok;
        {error, Reason} ->
            logger:error("Failed to start event store ~p: ~p", [StoreId, Reason]),
            {error, Reason}
    end.

%% @doc Start store subscriptions for the given store IDs.
%% Creates one evoq_store_subscription per domain store.
%% Called by hecate_boot_tracker after stores are ready.
-spec start_store_subscriptions([atom()]) -> ok.
start_store_subscriptions(StoreIds) ->
    lists:foreach(fun(StoreId) ->
        case evoq_store_subscription:start_link(StoreId) of
            {ok, _Pid} ->
                logger:info("Store subscription ready for ~p", [StoreId]);
            {error, Reason} ->
                logger:warning("Store subscription failed for ~p: ~p",
                               [StoreId, Reason])
        end
    end, StoreIds).

%%--------------------------------------------------------------------
%% @doc Stop the Hecate application.
%%
%% Sets lifecycle state to stopping, stops the socket listener,
%% cleans up the socket file and lifecycle files.
%% @end
%%--------------------------------------------------------------------
-spec stop(State) -> ok when
    State :: term().
stop(_State) ->
    logger:info("Stopping Hecate"),
    hecate_lifecycle:set_state(stopping),
    cowboy:stop_listener(hecate_socket_listener),
    %% Clean up socket file
    case hecate_socket:get_socket_path() of
        undefined -> ok;
        Path -> _ = file:delete(Path)
    end,
    hecate_lifecycle:cleanup(),
    ok.
