%%% @doc Supervisor for event_stack_groomed_v1 projection desk.
-module(event_stack_groomed_v1_to_event_stickies_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => pg_listener,
            start => {on_event_stack_groomed_v1_from_pg_project_to_sqlite_event_stickies, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
