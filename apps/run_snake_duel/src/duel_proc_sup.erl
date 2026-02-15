%%% @doc Dynamic supervisor for live snake duel processes.
%%%
%%% Each live duel gets its own duel_proc child.
%%% When the duel ends, the process terminates and is cleaned up.
%%% @end
-module(duel_proc_sup).
-behaviour(supervisor).

-export([start_link/0, start_duel/1]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec start_duel(map()) -> {ok, pid()} | {error, term()}.
start_duel(Config) ->
    supervisor:start_child(?MODULE, [Config]).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => simple_one_for_one,
        intensity => 10,
        period => 10
    },

    ChildSpec = #{
        id => duel_proc,
        start => {duel_proc, start_link, []},
        restart => temporary,
        type => worker
    },

    {ok, {SupFlags, [ChildSpec]}}.
