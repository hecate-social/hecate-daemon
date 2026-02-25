%%% @doc Supervisor for license_published_v1 -> catalog projection desk.
-module(license_published_v1_to_catalog_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{id => listener,
          start => {on_license_published_v1_to_sqlite_catalog, start_link, []},
          restart => permanent, type => worker}
    ],
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, Children}}.
