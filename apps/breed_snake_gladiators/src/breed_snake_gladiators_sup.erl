%%% @doc breed_snake_gladiators top-level supervisor
%%%
%%% Supervises the dynamic training process supervisor
%%% (one child per active training session).
%%% @end
-module(breed_snake_gladiators_sup).
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
        #{id => training_proc_sup,
          start => {training_proc_sup, start_link, []},
          restart => permanent, type => supervisor},
        #{id => gladiator_duel_proc_sup,
          start => {gladiator_duel_proc_sup, start_link, []},
          restart => permanent, type => supervisor}
    ],

    {ok, {SupFlags, Children}}.
