%%% @doc run_snake_duel top-level supervisor
%%%
%%% Supervises the dynamic match supervisor (one child per live match).
%%% @end
-module(run_snake_duel_sup).
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

    Children = [
        %% Dynamic supervisor for live duel processes
        #{id => duel_proc_sup,
          start => {duel_proc_sup, start_link, []},
          restart => permanent, type => supervisor}
    ],

    {ok, {SupFlags, Children}}.
