%%% @doc Top-level supervisor for query_deployments.
-module(query_deployments_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_deployments_store,
            start => {query_deployments_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: deployment_started_v1 -> deployments table
        #{
            id => deployment_started_v1_to_deployments_sup,
            start => {deployment_started_v1_to_deployments_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: release_deployed_v1 -> releases table
        #{
            id => release_deployed_v1_to_releases_sup,
            start => {release_deployed_v1_to_releases_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: rollout_staged_v1 -> rollout_stages table
        #{
            id => rollout_staged_v1_to_rollout_stages_sup,
            start => {rollout_staged_v1_to_rollout_stages_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> deployments table
        #{
            id => deployment_lifecycle_to_deployments_sup,
            start => {deployment_lifecycle_to_deployments_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: deployment_archived_v1 -> deployments table
        #{
            id => deployment_archived_v1_to_deployments_sup,
            start => {deployment_archived_v1_to_deployments_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
