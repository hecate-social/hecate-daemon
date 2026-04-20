%%% @doc Supervisor for project_briefcase_files.
%%%
%%% Phase 1: no children yet — the projection is registered with evoq
%%% at boot by `hecate_app`. Later phases may add a dedicated store
%%% worker or read-model cache.
%%% @end
-module(project_briefcase_files_sup).
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
