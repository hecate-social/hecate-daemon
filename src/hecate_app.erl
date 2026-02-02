%%%-------------------------------------------------------------------
%%% @doc Hecate application module.
%%%
%%% Starts the Hecate agent sidecar daemon.
%%% Ensures ReckonDB (event store) is started BEFORE any domain services.
%%%
%%% NOTE: reckon_db and evoq are started here, but stores are NOT configured
%%% centrally. Each domain supervisor starts its own store via
%%% reckon_db_sup:start_store/1 in its init/1. This follows VERTICAL SLICING.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_app).
-behaviour(application).

-export([start/2, stop/1]).

%%--------------------------------------------------------------------
%% @doc Start the Hecate application.
%%
%% Startup order is CRITICAL:
%% 1. reckon_db (embedded event store infrastructure) - MUST be first
%% 2. evoq (CQRS framework)
%% 3. hecate_sup (domain services start their own stores)
%% @end
%%--------------------------------------------------------------------
-spec start(StartType, StartArgs) -> {ok, Pid} | {error, Reason} when
    StartType :: application:start_type(),
    StartArgs :: term(),
    Pid :: pid(),
    Reason :: term().
start(_StartType, _StartArgs) ->
    logger:info("Starting Hecate 🗝️"),

    %% 1. Start ReckonDB infrastructure FIRST
    %% This starts reckon_db_sup but NO stores yet.
    %% Each domain supervisor will call reckon_db_sup:start_store/1.
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
            start_hecate_sup();
        {error, EvoqReason} ->
            logger:error("Failed to start Evoq: ~p", [EvoqReason]),
            {error, {evoq_start_failed, EvoqReason}}
    end.

%% @private Start Hecate supervisor
%% Domain supervisors will start their own ReckonDB stores.
start_hecate_sup() ->
    logger:info("Starting Hecate supervisor (domains will start their stores)..."),
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
