%%% @doc serve_llm top-level supervisor
%%%
%%% Starts this domain's ReckonDB store and supervises emitters/poller.
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
        %% Emitters: subscribe to domain events and publish to mesh
        {llm_capability_announced_v1_to_mesh,
            {llm_capability_announced_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [llm_capability_announced_v1_to_mesh]},
        {llm_capability_retracted_v1_to_mesh,
            {llm_capability_retracted_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [llm_capability_retracted_v1_to_mesh]},

        %% Model poller: polls Ollama and dispatches announce/retract commands
        {llm_model_poller,
            {llm_model_poller, start_link, []},
            permanent, 5000, worker, [llm_model_poller]}
    ],

    logger:info("[serve_llm] Supervisor started with ~p children", [length(Children)]),
    {ok, {SupFlags, Children}}.
