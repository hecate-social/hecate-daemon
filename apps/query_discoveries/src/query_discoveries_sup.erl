%%% @doc Top-level supervisor for query_discoveries.
-module(query_discoveries_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_discoveries_store,
            start => {query_discoveries_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: discovery_started_v1 -> discoveries table
        #{
            id => discovery_started_v1_to_discoveries_sup,
            start => {discovery_started_v1_to_discoveries_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: division_discovered_v1 -> discovered_divisions table
        #{
            id => division_discovered_v1_to_discovered_divisions_sup,
            start => {division_discovered_v1_to_discovered_divisions_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> discoveries table
        #{
            id => discovery_lifecycle_to_discoveries_sup,
            start => {discovery_lifecycle_to_discoveries_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: discovery_archived_v1 -> discoveries table
        #{
            id => discovery_archived_v1_to_discoveries_sup,
            start => {discovery_archived_v1_to_discoveries_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
