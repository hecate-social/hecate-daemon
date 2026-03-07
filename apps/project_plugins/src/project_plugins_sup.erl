%%% @doc Top-level supervisor for project_plugins (PRJ).
%%%
%%% Supervises the plugins read model store and all projection desks.
%%% Each projection writes to a shared named ETS table (plugins).
%%% @end
-module(project_plugins_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% Read model query facade (must start first — creates ETS table)
        #{
            id => project_plugins_store,
            start => {project_plugins_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: plugin_installed_v1 -> plugins ETS
        #{
            id => plugin_installed_v1_to_plugins,
            start => {evoq_projection, start_link, [plugin_installed_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: plugin_upgraded_v1 -> plugins ETS
        #{
            id => plugin_upgraded_v1_to_plugins,
            start => {evoq_projection, start_link, [plugin_upgraded_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: plugin_removed_v1 -> plugins ETS
        #{
            id => plugin_removed_v1_to_plugins,
            start => {evoq_projection, start_link, [plugin_removed_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: plugin_execution_started_v1 -> plugins ETS
        #{
            id => plugin_execution_started_v1_to_plugins,
            start => {evoq_projection, start_link, [plugin_execution_started_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: plugin_execution_stopped_v1 -> plugins ETS
        #{
            id => plugin_execution_stopped_v1_to_plugins,
            start => {evoq_projection, start_link, [plugin_execution_stopped_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: container_confirmed_up_v1 -> plugins ETS
        #{
            id => container_confirmed_up_v1_to_plugins,
            start => {evoq_projection, start_link, [container_confirmed_up_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: container_confirmed_down_v1 -> plugins ETS
        #{
            id => container_confirmed_down_v1_to_plugins,
            start => {evoq_projection, start_link, [container_confirmed_down_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: container_pull_started_v1 -> plugins ETS
        #{
            id => container_pull_started_v1_to_plugins,
            start => {evoq_projection, start_link, [container_pull_started_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: container_pull_cancelled_v1 -> plugins ETS
        #{
            id => container_pull_cancelled_v1_to_plugins,
            start => {evoq_projection, start_link, [container_pull_cancelled_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        },
        %% Projection: container_pull_completed_v1 -> plugins ETS
        #{
            id => container_pull_completed_v1_to_plugins,
            start => {evoq_projection, start_link, [container_pull_completed_v1_to_plugins, #{}]},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
