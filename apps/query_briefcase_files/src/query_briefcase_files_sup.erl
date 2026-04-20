%%% @doc Supervisor for query_briefcase_files.
%%%
%%% Phase 1: no children. Read endpoints are registered with the HTTP
%%% router (`hecate_api`) at daemon boot.
%%% @end
-module(query_briefcase_files_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 10
    },
    Children = [],
    {ok, {SupFlags, Children}}.
