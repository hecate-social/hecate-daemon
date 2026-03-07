%%% @doc Top-level supervisor for project_settings (PRJ).
%%%
%%% Starts the ETS store first (creates table), then the merged projection.
%%% @end
-module(project_settings_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% ETS store (must start first — creates table)
        #{id => project_settings_store,
          start => {project_settings_store, start_link, []},
          restart => permanent, type => worker},
        %% Merged projection: all settings events -> settings ETS
        #{id => settings_lifecycle_to_settings,
          start => {evoq_projection, start_link, [settings_lifecycle_to_settings, #{}]},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
