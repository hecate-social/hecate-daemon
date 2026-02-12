%%% @doc Top-level supervisor for query_division_alc.
%%% Supervises the SQLite store and all 18 projection desk supervisors.
-module(query_division_alc_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_division_alc_store,
            start => {query_division_alc_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Core lifecycle projections
        #{
            id => division_initiated_v1_to_divisions_sup,
            start => {division_initiated_v1_to_divisions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => division_archived_v1_to_divisions_sup,
            start => {division_archived_v1_to_divisions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => phase_started_v1_to_divisions_sup,
            start => {phase_started_v1_to_divisions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => phase_completed_v1_to_divisions_sup,
            start => {phase_completed_v1_to_divisions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% DnA domain projections
        #{
            id => aggregate_designed_v1_to_designed_aggregates_sup,
            start => {aggregate_designed_v1_to_designed_aggregates_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => event_designed_v1_to_designed_events_sup,
            start => {event_designed_v1_to_designed_events_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% AnP domain projections
        #{
            id => desk_planned_v1_to_planned_desks_sup,
            start => {desk_planned_v1_to_planned_desks_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => dependency_planned_v1_to_planned_dependencies_sup,
            start => {dependency_planned_v1_to_planned_dependencies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% TnI domain projections
        #{
            id => module_generated_v1_to_generated_modules_sup,
            start => {module_generated_v1_to_generated_modules_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => test_generated_v1_to_generated_tests_sup,
            start => {test_generated_v1_to_generated_tests_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => test_suite_run_v1_to_test_suites_sup,
            start => {test_suite_run_v1_to_test_suites_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => test_result_recorded_v1_to_test_results_sup,
            start => {test_result_recorded_v1_to_test_results_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% DnO domain projections
        #{
            id => release_deployed_v1_to_releases_sup,
            start => {release_deployed_v1_to_releases_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => rollout_staged_v1_to_rollout_stages_sup,
            start => {rollout_staged_v1_to_rollout_stages_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => health_check_registered_v1_to_health_checks_sup,
            start => {health_check_registered_v1_to_health_checks_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => incident_raised_v1_to_incidents_sup,
            start => {incident_raised_v1_to_incidents_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => incident_diagnosed_v1_to_diagnoses_sup,
            start => {incident_diagnosed_v1_to_diagnoses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        #{
            id => fix_applied_v1_to_fixes_sup,
            start => {fix_applied_v1_to_fixes_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
