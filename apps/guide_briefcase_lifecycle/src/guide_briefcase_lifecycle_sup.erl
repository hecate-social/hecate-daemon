%%% @doc guide_briefcase_lifecycle top-level supervisor
%%%
%%% Empty for now — emitters and process managers will be added later.
%%% @end
-module(guide_briefcase_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

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

    Children = [],

    {ok, {SupFlags, Children}}.
