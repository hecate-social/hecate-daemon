%%% @doc Desk supervisor: venture_setup_v1 -> ventures projection
-module(venture_setup_v1_to_ventures_sup).
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
            start => {on_venture_setup_v1_from_pg_project_to_sqlite_ventures, start_link, []},
            restart => permanent,
            type => worker
        }
    ],
    {ok, {SupFlags, Children}}.
