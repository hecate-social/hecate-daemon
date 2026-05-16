%%%-------------------------------------------------------------------
%%% @doc Hecate application module — tier-1 business bootstrap.
%%%
%%% boot_daemon (tier-0) is started as an OTP dependency; it owns the
%%% cluster cookie, reckon_db + evoq startup, store spawning, boot
%%% tracking, and post-boot sequencing. This module only:
%%%
%%%   1. Creates the namespaced directory layout
%%%   2. Clones the hecate-agents repo if needed
%%%   3. Writes lifecycle files + opens an early health-only socket
%%%   4. Hands the store catalog to boot_daemon
%%%   5. Starts the business supervisor (identity, realm_session,
%%%      ucan, plugin_loader)
%%%
%%% Store catalog stays here because it's domain knowledge — what
%%% bounded contexts this daemon has. boot_daemon owns the
%%% mechanics of spawning and tracking.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_app).
-behaviour(application).

-export([start/2, stop/1]).

%% Store definitions: {StoreId, SubDir, Label}
-define(STORES, [
    {settings_store,            "settings",            "Settings (identity, preferences)"},
    {realm_memberships_store,   "realm_memberships",   "Realm Memberships (join, confirm, revoke)"},
    {llm_store,                 "llm",                 "LLM (detection, status reporting)"},
    {licenses_store,            "licenses",            "Licenses (consumer lifecycle)"},
    {share_licenses_store,      "share_licenses",      "Share-Licenses (Phase D crypto grants)"},
    {license_offerings_store,   "license_offerings",   "License Offerings (author catalog)"},
    {procurements_store,        "procurements",        "Procurements (buying process)"},
    {sales_store,               "sales",               "Sales (selling process)"},
    {payments_store,            "payments",            "Payments (payment process)"},
    {plugins_store,             "plugins",             "Plugins (install/upgrade/remove)"},
    {launcher_store,            "launcher",            "Launcher (sidebar layout lifecycle)"},
    {mpong_store,               "mpong",               "MPong (mesh pong game lifecycle)"},
    {briefcase_store,           "briefcase",           "Briefcase (file upload, revise, move, archive, grant)"},
    {repo_store,                "repos",               "Repos (git-over-mesh lifecycle: initiate, rename, describe, archive)"},
    {mesh_publications_store,   "mesh_publications",   "Mesh publications (agent FACT publishes via /api/mesh/publish)"},
    {mesh_artifacts_store,      "mesh_artifacts",      "Mesh artifacts (agent content-sharing via /api/mesh/artifact/put)"}
]).

-define(SITE_STORES, [
    {site_store, "site", "Site (realm membership, cluster nodes)"}
]).

%%--------------------------------------------------------------------
%% @doc Start the Hecate application.
%% @end
%%--------------------------------------------------------------------
-spec start(application:start_type(), term()) -> {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    logger:info("Starting Hecate"),

    %% Raise macula QUIC rate limits for LAN mesh clusters
    application:set_env(macula, quic_max_conn_per_ip, 50),
    application:set_env(macula, quic_max_conn_global_per_sec, 200),

    %% Pubsub Phase 2 — opt in to publisher-end-to-end signed events.
    %% HECATE_PUBSUB_PUBLISHER_SIG=true → the daemon attaches a
    %% `publisher_sig' to every PUBLISH frame (macula >= 4.4.1), which
    %% relay stations carry onto the EVENT so it verifies end-to-end
    %% at every hop and the (publisher,seq) dedup becomes the cross-
    %% station loop kill. DO NOT enable until every relay is on macula
    %% >= 4.4.0 (a pre-4.4.0 relay would reject a PUBLISH carrying
    %% publisher_sig). Default off. HECATE_PUBSUB_STRICT_PUBLISHER_SIG=true
    %% additionally drops (rather than log+deliver) an inbound EVENT
    %% whose publisher_sig is present but invalid. See macula CHANGELOG
    %% 4.4.0-4.4.2 + macula-station/plans/PLAN_PUBSUB_E2E_SIGNED_EVENTS.md.
    set_macula_flag(pubsub_emit_publisher_sig, "HECATE_PUBSUB_PUBLISHER_SIG"),
    set_macula_flag(pubsub_strict_publisher_sig, "HECATE_PUBSUB_STRICT_PUBLISHER_SIG"),

    %% 1. Create namespaced directory layout
    shared_paths:ensure_layout(),

    %% 2. Ensure hecate-agents repo is cloned (non-blocking on failure)
    case hecate_agents_repo:ensure() of
        {ok, AgentsPath} ->
            logger:info("hecate-agents available at ~s", [AgentsPath]);
        {error, _} ->
            logger:warning("hecate-agents not available — some features may be limited")
    end,

    %% 3. Write lifecycle files (daemon.pid + state = starting)
    hecate_lifecycle:init(),

    %% 4. Start socket with minimal health-only dispatch
    start_early_socket(),

    %% 5. Hand the store catalog to boot_daemon. It's already running
    %%    (declared as a dep in hecate.app.src + release config). Store
    %%    spawning, manager-polling, post-boot subscriptions, routes,
    %%    projection wait and peer connection all happen in tier-0.
    AllStores = ?STORES ++ ?SITE_STORES,
    StoreIds = [Id || {Id, _, _} <- AllStores],
    logger:info("Registering ~b stores with boot_daemon", [length(AllStores)]),
    boot_daemon:register_stores(AllStores),

    %% 6. Self-instrument daemon stores for /metrics
    hecate_plugin_metrics:init(<<"hecate">>),
    lists:foreach(fun({StoreId, _, _}) ->
        hecate_plugin_telemetry:attach(<<"hecate">>, StoreId)
    end, AllStores),

    %% 7. Start the business supervisor (identity, realm_session, UCAN,
    %%    plugin_loader). These workers may want to read from stores;
    %%    they tolerate store-not-ready via handle_continue/whereis
    %%    guards because the stores are still booting in parallel.
    hecate_sup:start_link(StoreIds).

%% @private Start the Unix socket with a minimal startup-health-only dispatch.
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

%%--------------------------------------------------------------------
%% @doc Stop the Hecate application.
%% @end
%%--------------------------------------------------------------------
-spec stop(term()) -> ok.
stop(_State) ->
    logger:info("Stopping Hecate"),
    hecate_lifecycle:set_state(stopping),
    cowboy:stop_listener(hecate_socket_listener),
    case hecate_socket:get_socket_path() of
        undefined -> ok;
        Path -> _ = file:delete(Path)
    end,
    hecate_lifecycle:cleanup(),
    ok.

%% Mirror a boolean `HECATE_*' env var into a `macula' application
%% env key. Recognised true values: "true" / "1" (case-insensitive).
%% Anything else (incl. unset) leaves the macula default in place —
%% we only ever set it to `true', never explicitly to `false', so a
%% sys.config override still wins for the off state.
-spec set_macula_flag(atom(), string()) -> ok.
set_macula_flag(Key, EnvVar) ->
    case env_truthy(os:getenv(EnvVar)) of
        true ->
            application:set_env(macula, Key, true),
            logger:notice("[hecate] macula ~p enabled via ~s", [Key, EnvVar]);
        false ->
            ok
    end.

env_truthy(false)   -> false;
env_truthy(V)       ->
    lists:member(string:lowercase(V), ["true", "1", "yes", "on"]).
