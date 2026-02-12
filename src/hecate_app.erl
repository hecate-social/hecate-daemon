%%%-------------------------------------------------------------------
%%% @doc Hecate application module.
%%%
%%% Starts the Hecate agent sidecar daemon.
%%% Ensures ReckonDB (event store) and Evoq are started, then creates
%%% TWO shared event stores:
%%%   - hecate_event_store: node infrastructure domains
%%%   - dev_studio_store: venture lifecycle (guide_venture_lifecycle,
%%%     guide_division_alc, and their query services)
%%% Streams within each store separate events by aggregate.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_app).
-behaviour(application).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start/2, stop/1]).

%%--------------------------------------------------------------------
%% @doc Start the Hecate application.
%%
%% Startup order is CRITICAL:
%% 1. reckon_db (embedded event store infrastructure)
%% 2. evoq (CQRS framework)
%% 3. hecate_event_store (ONE shared store for all domains)
%% 4. hecate_sup (domain services use the shared store)
%% @end
%%--------------------------------------------------------------------
-spec start(StartType, StartArgs) -> {ok, Pid} | {error, Reason} when
    StartType :: application:start_type(),
    StartArgs :: term(),
    Pid :: pid(),
    Reason :: term().
start(_StartType, _StartArgs) ->
    logger:info("Starting Hecate 🗝️"),

    %% 1. Start ReckonDB infrastructure
    logger:info("Starting ReckonDB infrastructure..."),
    case application:ensure_all_started(reckon_db) of
        {ok, _ReckonApps} ->
            logger:info("ReckonDB infrastructure ready"),
            start_evoq();
        {error, ReckonReason} ->
            logger:error("Failed to start ReckonDB: ~p", [ReckonReason]),
            {error, {reckon_db_start_failed, ReckonReason}}
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
    HecateConfig = #store_config{
        store_id = hecate_event_store,
        data_dir = "data/reckon/hecate",
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
    DevStudioConfig = #store_config{
        store_id = dev_studio_store,
        data_dir = "data/reckon/dev_studio",
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
%% @end
%%--------------------------------------------------------------------
-spec stop(State) -> ok when
    State :: term().
stop(_State) ->
    logger:info("Stopping Hecate 🗝️"),
    ok.
