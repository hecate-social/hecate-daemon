%%% @doc query_snake_duel top-level supervisor
%%%
%%% Supervises:
%%% - SQLite store for match read models
%%% - Projections: duel_started_v1 / duel_ended_v1 -> matches
%%% @end
-module(query_snake_duel_sup).
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
        %% SQLite store (must start first)
        #{id => query_snake_duel_store,
          start => {query_snake_duel_store, start_link, []},
          restart => permanent, type => worker}
    ],

    {ok, {SupFlags, Children}}.
