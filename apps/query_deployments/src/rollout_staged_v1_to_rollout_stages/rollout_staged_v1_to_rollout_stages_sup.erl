%%% @doc Supervisor for rollout_staged_v1 projection desk.
-module(rollout_staged_v1_to_rollout_stages_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        #{
            id => pg_listener,
            start => {on_rollout_staged_v1_from_pg_project_to_sqlite_rollout_stages, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
