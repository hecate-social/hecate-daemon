%%% @doc Top-level supervisor for query_plans.
-module(query_plans_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_plans_store,
            start => {query_plans_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: plan_started_v1 -> plans table
        #{
            id => plan_started_v1_to_plans_sup,
            start => {plan_started_v1_to_plans_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: desk_planned_v1 -> planned_desks table
        #{
            id => desk_planned_v1_to_planned_desks_sup,
            start => {desk_planned_v1_to_planned_desks_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: dependency_planned_v1 -> planned_dependencies table
        #{
            id => dependency_planned_v1_to_planned_dependencies_sup,
            start => {dependency_planned_v1_to_planned_dependencies_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> plans table
        #{
            id => plan_lifecycle_to_plans_sup,
            start => {plan_lifecycle_to_plans_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: plan_archived_v1 -> plans table
        #{
            id => plan_archived_v1_to_plans_sup,
            start => {plan_archived_v1_to_plans_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
