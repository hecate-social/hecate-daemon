%%% @doc mentor_agents top-level supervisor
%%%
%%% Starts this domain's ReckonDB store and supervises emitters.
%%% VERTICAL SLICING: This domain owns its own event store.
-module(mentor_agents_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for calls to reckon_db_sup (excluded from PLT)
-dialyzer({nowarn_function, [init/1]}).

-define(STORE_ID, mentor_agents_store).
-define(DATA_DIR, "data/reckon/mentor_agents").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
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
        {learning_validated_v1_to_mesh,
            {learning_validated_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [learning_validated_v1_to_mesh]},
        {learning_endorsed_v1_to_mesh,
            {learning_endorsed_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [learning_endorsed_v1_to_mesh]},
        {expertise_declared_v1_to_mesh,
            {expertise_declared_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [expertise_declared_v1_to_mesh]},
        {expertise_withdrawn_v1_to_mesh,
            {expertise_withdrawn_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [expertise_withdrawn_v1_to_mesh]}
    ],

    {ok, {SupFlags, Children}}.
