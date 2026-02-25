%%% @doc Top-level supervisor for project_plugins (PRJ).
%%%
%%% Supervises the SQLite store and all projection desk supervisors.
%%% @end
-module(project_plugins_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => project_plugins_store,
            start => {project_plugins_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: plugin_installed_v1 -> plugins table
        #{
            id => plugin_installed_v1_to_plugins_sup,
            start => {plugin_installed_v1_to_plugins_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: plugin_upgraded_v1 -> plugins table
        #{
            id => plugin_upgraded_v1_to_plugins_sup,
            start => {plugin_upgraded_v1_to_plugins_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: plugin_removed_v1 -> plugins table
        #{
            id => plugin_removed_v1_to_plugins_sup,
            start => {plugin_removed_v1_to_plugins_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
