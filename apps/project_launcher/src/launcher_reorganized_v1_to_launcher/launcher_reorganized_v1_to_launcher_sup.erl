%%% @doc Supervisor for launcher_reorganized_v1 -> launcher projection.
-module(launcher_reorganized_v1_to_launcher_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => listener,
          start => {on_launcher_reorganized_v1_to_sqlite_launcher, start_link, []},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
