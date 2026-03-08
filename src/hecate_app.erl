%%%-------------------------------------------------------------------
%%% @doc Hecate application module.
%%%
%%% Starts the Hecate agent sidecar daemon.
%%%
%%% Startup order is CRITICAL:
%%% 1. Directory layout (ensure ~/.hecate/hecate-daemon/* exists)
%%% 2. Lifecycle files (daemon.pid, daemon.state = starting)
%%% 3. Unix socket with minimal health-only dispatch (clients see ready:false)
%%% 4. ReckonDB (embedded event store infrastructure)
%%% 5. Evoq (CQRS framework)
%%% 6. Domain event stores (one per bounded context)
%%% 7. hecate_sup (domain services)
%%% 8. [Domain apps start via release config]
%%% 9. Store subscriptions (started by hecate_api_app, AFTER projections register)
%%%
%%% The socket becomes fully operational later when hecate_api_app
%%% hot-swaps the full route table and sets state to `running`.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_app).
-behaviour(application).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start/2, stop/1]).
-export([start_store_subscriptions/0]).

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

    %% 1. Create namespaced directory layout
    shared_paths:ensure_layout(),

    %% 2. Write lifecycle files (daemon.pid + state = starting)
    hecate_lifecycle:init(),

    %% 3. Start socket with minimal health-only dispatch
    start_early_socket(),

    %% 4. Start ReckonDB infrastructure
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
                {'_', [{"/health", hecate_api_startup_health, []}]}
            ]),
            case hecate_socket:start_listener(Path, StartupDispatch) of
                ok ->
                    logger:info("Early socket ready (health-only)");
                {error, Reason} ->
                    logger:warning("Early socket failed: ~p", [Reason])
            end
    end.

%% @private Start Evoq (CQRS framework)
start_evoq() ->
    logger:info("Starting Evoq (CQRS framework)..."),
    case application:ensure_all_started(evoq) of
        {ok, _EvoqApps} ->
            logger:info("Evoq started successfully"),
            start_event_stores();
        {error, EvoqReason} ->
            logger:error("Failed to start Evoq: ~p", [EvoqReason]),
            {error, {evoq_start_failed, EvoqReason}}
    end.

%% @private Start domain event stores (one per bounded context).
%% All stores start in parallel since Ra clusters are independent.
start_event_stores() ->
    Stores = [
        {settings_store,            "settings",            "Settings (identity, preferences)"},
        {realm_memberships_store,   "realm_memberships",   "Realm Memberships (join, confirm, revoke)"},
        {llm_store,                 "llm",                 "LLM (detection, status reporting)"},
        {licenses_store,            "licenses",            "Licenses (appstore lifecycle)"},
        {plugins_store,             "plugins",             "Plugins (install/upgrade/remove)"},
        {launcher_store,            "launcher",            "Launcher (sidebar layout lifecycle)"}
    ],
    start_stores_parallel(Stores).

%% @private Start all stores concurrently using async tasks.
%% Each Ra cluster is independent so there's no ordering dependency.
start_stores_parallel(Stores) ->
    logger:info("Starting ~b event stores in parallel...", [length(Stores)]),
    StartTime = erlang:monotonic_time(millisecond),
    %% Spawn a process per store, collect results
    Refs = lists:map(fun({StoreId, SubDir, Label}) ->
        Ref = make_ref(),
        Parent = self(),
        spawn_link(fun() ->
            logger:info("Starting ~s event store (~p)...", [Label, StoreId]),
            DataDir = shared_paths:reckon_path(SubDir),
            ok = filelib:ensure_path(DataDir),
            Config = #store_config{
                store_id = StoreId,
                data_dir = DataDir,
                mode = single,
                writer_pool_size = 5,
                reader_pool_size = 5,
                gateway_pool_size = 2,
                options = #{}
            },
            Result = start_store(Config),
            Parent ! {store_started, Ref, StoreId, Result}
        end),
        {Ref, StoreId}
    end, Stores),
    %% Wait for all stores to complete
    case collect_store_results(Refs, []) of
        ok ->
            Duration = erlang:monotonic_time(millisecond) - StartTime,
            logger:info("All ~b event stores ready in ~bms", [length(Stores), Duration]),
            %% NOTE: store subscriptions are started LATER by hecate_api_app:start/2,
            %% after all domain apps (and their projections) have registered with the
            %% type registry. This ensures historical events replayed from the $all
            %% subscription are delivered to projections instead of being dropped.
            start_hecate_sup();
        {error, _} = Error ->
            Error
    end.

%% @private Collect results from parallel store startup.
collect_store_results([], _Acc) ->
    ok;
collect_store_results([{Ref, StoreId} | Rest], Acc) ->
    receive
        {store_started, Ref, StoreId, ok} ->
            collect_store_results(Rest, [StoreId | Acc]);
        {store_started, Ref, StoreId, {error, Reason}} ->
            logger:error("Failed to start ~p: ~p", [StoreId, Reason]),
            {error, {StoreId, Reason}}
    after 30000 ->
        logger:error("Timeout waiting for store ~p to start", [StoreId]),
        {error, {StoreId, timeout}}
    end.

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
            {error, Reason}
    end.

%% @private Start store subscriptions (evoq 1.6.0 bridge).
%% Creates one evoq_store_subscription per domain store.
%% These route events from reckon-db stores to evoq behaviours
%% (evoq_event_handler, evoq_projection, evoq_process_manager).
start_store_subscriptions() ->
    Stores = [settings_store, realm_memberships_store, llm_store,
              licenses_store, plugins_store,
              launcher_store],
    lists:foreach(fun(StoreId) ->
        case evoq_store_subscription:start_link(StoreId) of
            {ok, _Pid} ->
                logger:info("Store subscription ready for ~p", [StoreId]);
            {error, Reason} ->
                logger:warning("Store subscription failed for ~p: ~p",
                               [StoreId, Reason])
        end
    end, Stores).

%% @private Start Hecate supervisor
start_hecate_sup() ->
    logger:info("Starting Hecate supervisor..."),
    hecate_sup:start_link().

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
