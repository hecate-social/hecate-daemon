%%% @doc Supervisor for health_check_registered_v1 projection desk.
-module(health_check_registered_v1_to_health_checks_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => pg_listener,
            start => {on_health_check_registered_v1_from_pg_project_to_sqlite_health_checks, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
