%%% @doc Supervisor for plugin_installed_v1 -> plugins projection.
-module(plugin_installed_v1_to_plugins_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => listener,
          start => {on_plugin_installed_v1_to_sqlite_plugins, start_link, []},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
