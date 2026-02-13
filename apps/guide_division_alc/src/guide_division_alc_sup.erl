%%% @doc guide_division_alc top-level supervisor
%%%
%%% Supervises mesh and PG emitters for division lifecycle events.
%%% PG emitters subscribe to the event store via evoq and broadcast
%%% events to OTP process groups for internal integration.
%%% @end
-module(guide_division_alc_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    MeshEmitters = [
        #{id => division_initiated_v1_to_mesh,
          start => {division_initiated_v1_to_mesh, start_link, []},
          restart => permanent, type => worker}
    ],

    PgEmitters = [
        #{id => division_initiated_v1_to_pg,
          start => {division_initiated_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => phase_started_v1_to_pg,
          start => {phase_started_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => phase_paused_v1_to_pg,
          start => {phase_paused_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => phase_resumed_v1_to_pg,
          start => {phase_resumed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => phase_completed_v1_to_pg,
          start => {phase_completed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => division_archived_v1_to_pg,
          start => {division_archived_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => aggregate_designed_v1_to_pg,
          start => {aggregate_designed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => event_designed_v1_to_pg,
          start => {event_designed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => desk_planned_v1_to_pg,
          start => {desk_planned_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => dependency_planned_v1_to_pg,
          start => {dependency_planned_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => module_generated_v1_to_pg,
          start => {module_generated_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => test_generated_v1_to_pg,
          start => {test_generated_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => test_suite_run_v1_to_pg,
          start => {test_suite_run_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => test_result_recorded_v1_to_pg,
          start => {test_result_recorded_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => release_deployed_v1_to_pg,
          start => {release_deployed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => rollout_staged_v1_to_pg,
          start => {rollout_staged_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => health_check_registered_v1_to_pg,
          start => {health_check_registered_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => health_status_recorded_v1_to_pg,
          start => {health_status_recorded_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => incident_raised_v1_to_pg,
          start => {incident_raised_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => incident_diagnosed_v1_to_pg,
          start => {incident_diagnosed_v1_to_pg, start_link, []},
          restart => permanent, type => worker},
        #{id => fix_applied_v1_to_pg,
          start => {fix_applied_v1_to_pg, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, PgEmitters ++ MeshEmitters}}.
