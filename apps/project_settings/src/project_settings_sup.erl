%%% @doc Supervisor for project_settings.
%%%
%%% Starts store first, then 6 self-subscribing projection workers.
-module(project_settings_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% SQLite store (must start first)
        #{id => project_settings_store,
          start => {project_settings_store, start_link, []},
          restart => permanent, type => worker},

        %% Projection workers (each subscribes to its own event type)
        worker(settings_initiated_v1_to_settings),
        worker(node_paired_v1_to_settings),
        worker(node_unpaired_v1_to_settings),
        worker(api_key_configured_v1_to_api_keys),
        worker(api_key_removed_v1_to_api_keys),
        worker(preferences_updated_v1_to_settings)
    ],
    {ok, {SupFlags, Children}}.

worker(Module) ->
    #{id => Module,
      start => {Module, start_link, []},
      restart => permanent, type => worker}.
