%%% @doc Top-level supervisor for query_rescues.
-module(query_rescues_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_rescues_store,
            start => {query_rescues_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: rescue_started_v1 -> rescues table
        #{
            id => rescue_started_v1_to_rescues_sup,
            start => {rescue_started_v1_to_rescues_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: incident_diagnosed_v1 -> diagnoses table
        #{
            id => incident_diagnosed_v1_to_diagnoses_sup,
            start => {incident_diagnosed_v1_to_diagnoses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: fix_applied_v1 -> fixes table
        #{
            id => fix_applied_v1_to_fixes_sup,
            start => {fix_applied_v1_to_fixes_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: lifecycle events (paused/resumed/completed) -> rescues table
        #{
            id => rescue_lifecycle_to_rescues_sup,
            start => {rescue_lifecycle_to_rescues_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: rescue_archived_v1 -> rescues table
        #{
            id => rescue_archived_v1_to_rescues_sup,
            start => {rescue_archived_v1_to_rescues_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
