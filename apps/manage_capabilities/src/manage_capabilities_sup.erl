%%% @doc manage_capabilities top-level supervisor
%%%
%%% Starts this domain's ReckonDB store and supervises emitters.
%%% VERTICAL SLICING: This domain owns its own event store.
-module(manage_capabilities_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for calls to reckon_db_sup (excluded from PLT)
-dialyzer({nowarn_function, [init/1]}).

-define(STORE_ID, manage_capabilities_store).
-define(DATA_DIR, "data/reckon/capabilities").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Start this domain's ReckonDB store
    %% Each domain owns its infrastructure (vertical slicing)
    StoreConfig = #store_config{
        store_id = ?STORE_ID,
        data_dir = ?DATA_DIR,
        mode = single,
        writer_pool_size = 5,
        reader_pool_size = 5,
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
        %% Emitters: publish domain events to mesh as integration facts
        {capability_announced_v1_to_mesh,
            {capability_announced_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [capability_announced_v1_to_mesh]},
        {capability_updated_v1_to_mesh,
            {capability_updated_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [capability_updated_v1_to_mesh]},
        {capability_retracted_v1_to_mesh,
            {capability_retracted_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [capability_retracted_v1_to_mesh]},

        %% Process Managers: react to cross-domain events
        {on_llm_detected_announce_capability,
            {on_llm_detected_announce_capability, start_link, []},
            permanent, 5000, worker, [on_llm_detected_announce_capability]},
        {on_llm_removed_retract_capability,
            {on_llm_removed_retract_capability, start_link, []},
            permanent, 5000, worker, [on_llm_removed_retract_capability]}
    ],

    {ok, {SupFlags, Children}}.
