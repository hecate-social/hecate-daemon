%%% @doc Top-level supervisor for test_division.
%%%
%%% Starts the embedded ReckonDB store and emitter workers.
%%% @end
-module(test_division_sup).
-behaviour(supervisor).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    StoreConfig = #store_config{
        store_id = test_division_store,
        data_dir = "data/reckon/test_division"
    },
    Children = [
        %% Embedded ReckonDB store (must start first)
        #{
            id => test_division_store,
            start => {reckon_db_sup, start_store, [StoreConfig]},
            restart => permanent,
            type => supervisor
        },
        %% Emitters
        #{
            id => testing_started_v1_to_mesh,
            start => {testing_started_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => test_suite_run_v1_to_mesh,
            start => {test_suite_run_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        },
        #{
            id => test_result_recorded_v1_to_mesh,
            start => {test_result_recorded_v1_to_mesh, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
