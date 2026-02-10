%%% @doc Top-level supervisor for query_generations.
-module(query_generations_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_generations_store,
            start => {query_generations_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: generation_started_v1 -> generations table
        #{
            id => generation_started_v1_to_generations_sup,
            start => {generation_started_v1_to_generations_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: module_generated_v1 -> generated_modules table
        #{
            id => module_generated_v1_to_generated_modules_sup,
            start => {module_generated_v1_to_generated_modules_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: test_generated_v1 -> generated_tests table
        #{
            id => test_generated_v1_to_generated_tests_sup,
            start => {test_generated_v1_to_generated_tests_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> generations table
        #{
            id => generation_lifecycle_to_generations_sup,
            start => {generation_lifecycle_to_generations_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: generation_archived_v1 -> generations table
        #{
            id => generation_archived_v1_to_generations_sup,
            start => {generation_archived_v1_to_generations_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
