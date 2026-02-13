%%% @doc Supervisor for storm_phase_advanced_v1 projection desk.
-module(storm_phase_advanced_v1_to_storm_sessions_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => pg_listener,
            start => {on_storm_phase_advanced_v1_from_pg_project_to_sqlite_storm_sessions, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
