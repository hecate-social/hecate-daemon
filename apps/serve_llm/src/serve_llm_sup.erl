%%% @doc serve_llm top-level supervisor
%%%
%%% Starts this domain's ReckonDB store and supervises emitters/pollers.
%%% VERTICAL SLICING: This domain owns its own event store.
-module(serve_llm_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for calls to reckon_db_sup (excluded from PLT)
-dialyzer({nowarn_function, [init/1]}).

-define(STORE_ID, serve_llm_store).
-define(DATA_DIR, "data/reckon/llm").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Start this domain's ReckonDB store
    %% Each domain owns its infrastructure (vertical slicing)
    StoreConfig = #store_config{
        store_id = ?STORE_ID,
        data_dir = ?DATA_DIR,
        mode = single,
        writer_pool_size = 3,
        reader_pool_size = 3,
        gateway_pool_size = 1,
        options = #{}
    },
    case reckon_db_sup:start_store(StoreConfig) of
        {ok, _Pid} ->
            logger:info("Started store ~p", [?STORE_ID]);
        {error, {already_started, _Pid}} ->
            logger:info("Store ~p already running", [?STORE_ID]);
        {error, Reason} ->
            logger:error("Failed to start store ~p: ~p", [?STORE_ID, Reason]),
            exit({failed_to_start_store, ?STORE_ID, Reason})
    end,

    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% manage_providers: provider registry (must start before detect_llms)
        {manage_providers,
            {manage_providers, start_link, []},
            permanent, 5000, worker, [manage_providers]},

        %% detect_llms: polls local providers, emits llm_detected/removed events
        {detect_llms,
            {detect_llms, start_link, []},
            permanent, 5000, worker, [detect_llms]},

        %% chat_to_llm_responder: handles chat requests from mesh
        {chat_to_llm_responder,
            {chat_to_llm_responder, start_link, []},
            permanent, 5000, worker, [chat_to_llm_responder]},

        %% list_available_llms_responder: handles list requests from mesh
        {list_available_llms_responder,
            {list_available_llms_responder, start_link, []},
            permanent, 5000, worker, [list_available_llms_responder]},

        %% check_llm_health_responder: handles health requests from mesh
        {check_llm_health_responder,
            {check_llm_health_responder, start_link, []},
            permanent, 5000, worker, [check_llm_health_responder]},

        %% report_llm_status: periodically checks model availability
        {report_llm_status,
            {report_llm_status, start_link, []},
            permanent, 5000, worker, [report_llm_status]}
    ],

    logger:info("[serve_llm] Supervisor started with ~p children", [length(Children)]),
    {ok, {SupFlags, Children}}.
