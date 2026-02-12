%%% @doc Top-level supervisor for query_venture_lifecycle.
-module(query_venture_lifecycle_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_venture_lifecycle_store,
            start => {query_venture_lifecycle_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: venture_initiated_v1 -> ventures table
        #{
            id => venture_initiated_v1_to_ventures_sup,
            start => {venture_initiated_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: venture_archived_v1 -> ventures table
        #{
            id => venture_archived_v1_to_ventures_sup,
            start => {venture_archived_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: discovery_started_v1 -> ventures table
        #{
            id => discovery_started_v1_to_ventures_sup,
            start => {discovery_started_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: division_identified_v1 -> discovered_divisions table
        #{
            id => division_identified_v1_to_discovered_divisions_sup,
            start => {division_identified_v1_to_discovered_divisions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: discovery_completed_v1 -> ventures table
        #{
            id => discovery_completed_v1_to_ventures_sup,
            start => {discovery_completed_v1_to_ventures_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
