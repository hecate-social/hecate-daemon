%%% @doc Top-level supervisor for query_monitoring.
-module(query_monitoring_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_monitoring_store,
            start => {query_monitoring_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: monitoring_started_v1 -> monitorings table
        #{
            id => monitoring_started_v1_to_monitorings_sup,
            start => {monitoring_started_v1_to_monitorings_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: health_check_registered_v1 -> health_checks table
        #{
            id => health_check_registered_v1_to_health_checks_sup,
            start => {health_check_registered_v1_to_health_checks_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: health_status_recorded_v1 -> health_checks table (UPDATE)
        #{
            id => health_status_recorded_v1_to_health_checks_sup,
            start => {health_status_recorded_v1_to_health_checks_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: incident_raised_v1 -> incidents table
        #{
            id => incident_raised_v1_to_incidents_sup,
            start => {incident_raised_v1_to_incidents_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> monitorings table
        #{
            id => monitoring_lifecycle_to_monitorings_sup,
            start => {monitoring_lifecycle_to_monitorings_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: monitoring_archived_v1 -> monitorings table
        #{
            id => monitoring_archived_v1_to_monitorings_sup,
            start => {monitoring_archived_v1_to_monitorings_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
