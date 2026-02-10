%%% @doc Top-level supervisor for query_designs.
-module(query_designs_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_designs_store,
            start => {query_designs_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: design_started_v1 -> designs table
        #{
            id => design_started_v1_to_designs_sup,
            start => {design_started_v1_to_designs_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: aggregate_designed_v1 -> designed_aggregates table
        #{
            id => aggregate_designed_v1_to_designed_aggregates_sup,
            start => {aggregate_designed_v1_to_designed_aggregates_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: event_designed_v1 -> designed_events table
        #{
            id => event_designed_v1_to_designed_events_sup,
            start => {event_designed_v1_to_designed_events_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> designs table
        #{
            id => design_lifecycle_to_designs_sup,
            start => {design_lifecycle_to_designs_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: design_archived_v1 -> designs table
        #{
            id => design_archived_v1_to_designs_sup,
            start => {design_archived_v1_to_designs_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
