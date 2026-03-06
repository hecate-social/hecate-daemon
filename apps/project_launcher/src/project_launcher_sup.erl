%%% @doc Top-level supervisor for project_launcher (PRJ).
%%%
%%% Supervises the SQLite store and all projection desk supervisors.
%%% @end
-module(project_launcher_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => project_launcher_store,
            start => {project_launcher_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: launcher_initialized_v1 -> launcher tables
        #{
            id => launcher_initialized_v1_to_launcher_sup,
            start => {launcher_initialized_v1_to_launcher_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: entry_registered_v1 -> launcher_entries + launcher_groups
        #{
            id => entry_registered_v1_to_launcher_sup,
            start => {entry_registered_v1_to_launcher_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: entry_unregistered_v1 -> launcher_entries (DELETE)
        #{
            id => entry_unregistered_v1_to_launcher_sup,
            start => {entry_unregistered_v1_to_launcher_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: launcher_reorganized_v1 -> rebuild launcher tables
        #{
            id => launcher_reorganized_v1_to_launcher_sup,
            start => {launcher_reorganized_v1_to_launcher_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
