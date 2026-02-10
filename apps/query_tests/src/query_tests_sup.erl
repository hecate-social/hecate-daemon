%%% @doc Top-level supervisor for query_tests.
-module(query_tests_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_tests_store,
            start => {query_tests_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: testing_started_v1 -> testings table
        #{
            id => testing_started_v1_to_testings_sup,
            start => {testing_started_v1_to_testings_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: test_suite_run_v1 -> test_suites table
        #{
            id => test_suite_run_v1_to_test_suites_sup,
            start => {test_suite_run_v1_to_test_suites_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: test_result_recorded_v1 -> test_results table
        #{
            id => test_result_recorded_v1_to_test_results_sup,
            start => {test_result_recorded_v1_to_test_results_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> testings table
        #{
            id => testing_lifecycle_to_testings_sup,
            start => {testing_lifecycle_to_testings_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: testing_archived_v1 -> testings table
        #{
            id => testing_archived_v1_to_testings_sup,
            start => {testing_archived_v1_to_testings_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
