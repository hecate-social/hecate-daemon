%%% @doc query_snake_gladiators top-level supervisor
%%%
%%% Supervises:
%%% - SQLite store for gladiator training read models
%%% @end
-module(query_snake_gladiators_sup).
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
        #{id => query_snake_gladiators_store,
          start => {query_snake_gladiators_store, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
