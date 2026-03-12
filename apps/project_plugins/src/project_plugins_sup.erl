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
        %% Merged projection: all plugin lifecycle events -> plugins ETS
        %% Single projection eliminates race conditions between separate
        %% projections competing for the same ETS table.
        #{
            id => plugin_lifecycle_to_plugins,
            start => {evoq_projection, start_link, [plugin_lifecycle_to_plugins, #{}, #{store_id => plugins_store}]},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
