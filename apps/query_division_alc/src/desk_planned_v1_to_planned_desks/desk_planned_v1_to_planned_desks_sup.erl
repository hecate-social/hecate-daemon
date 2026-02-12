%%% @doc Supervisor for desk_planned_v1 projection desk.
-module(desk_planned_v1_to_planned_desks_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => pg_listener,
            start => {on_desk_planned_v1_from_pg_project_to_sqlite_planned_desks, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
