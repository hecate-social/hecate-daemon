%%%-------------------------------------------------------------------
%%% @doc Hecate application module.
%%%
%%% Starts the Hecate agent sidecar daemon.
%%%
%%% Startup order is CRITICAL:
%%% 1. Lifecycle files (daemon.pid, daemon.state = starting)
%%% 2. Unix socket with minimal health-only dispatch (clients see ready:false)
%%% 3. ReckonDB (embedded event store infrastructure)
%%% 4. Evoq (CQRS framework)
%%% 5. Shared event stores (hecate_event_store, dev_studio_store)
%%% 6. hecate_sup (domain services)
%%%
%%% The socket becomes fully operational later when hecate_api_app
%%% hot-swaps the full route table and sets state to `running`.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_app).
-behaviour(application).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start/2, stop/1]).

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

    %% 1. Write lifecycle files (daemon.pid + state = starting)
    hecate_lifecycle:init(),

    %% 2. Start socket with minimal health-only dispatch
    start_early_socket(),

    %% 3. Start ReckonDB infrastructure
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
            start_event_store();
        {error, EvoqReason} ->
            logger:error("Failed to start Evoq: ~p", [EvoqReason]),
            {error, {evoq_start_failed, EvoqReason}}
    end.

%% @private Start the shared event stores.
%% Two stores: hecate_event_store (node infra) + dev_studio_store (venture lifecycle).
start_event_store() ->
    logger:info("Starting shared event store (hecate_event_store)..."),
    HecateDataDir = shared_paths:db_path("reckon/hecate"),
    ok = filelib:ensure_path(HecateDataDir),
    HecateConfig = #store_config{
        store_id = hecate_event_store,
        data_dir = HecateDataDir,
        mode = single,
        writer_pool_size = 10,
        reader_pool_size = 10,
        gateway_pool_size = 2,
        options = #{}
    },
    case start_store(HecateConfig) of
        ok -> start_dev_studio_store();
        {error, Reason} ->
            logger:error("Failed to start hecate_event_store: ~p", [Reason]),
            {error, {event_store_start_failed, Reason}}
    end.

%% @private Start the dev_studio_store for venture lifecycle domains.
start_dev_studio_store() ->
    logger:info("Starting dev studio event store (dev_studio_store)..."),
    DevStudioDataDir = shared_paths:db_path("reckon/dev_studio"),
    ok = filelib:ensure_path(DevStudioDataDir),
    DevStudioConfig = #store_config{
        store_id = dev_studio_store,
        data_dir = DevStudioDataDir,
        mode = single,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 2,
        options = #{}
    },
    case start_store(DevStudioConfig) of
        ok ->
            logger:info("Dev studio event store ready"),
            start_hecate_sup();
        {error, Reason} ->
            logger:error("Failed to start dev_studio_store: ~p", [Reason]),
            {error, {dev_studio_store_start_failed, Reason}}
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
