%%% @doc Spoke supervisor: torch_archived_v1 -> torches projection
%%% Supervises the pg listener that triggers the projection.
-module(torch_archived_v1_to_torches_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },
    Children = [
        #{
            id => pg_listener,
            start => {on_torch_archived_v1_from_pg_project_to_sqlite_torches, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {SupFlags, Children}}.
