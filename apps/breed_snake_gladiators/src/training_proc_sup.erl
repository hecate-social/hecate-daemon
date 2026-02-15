%%% @doc Dynamic supervisor for gladiator training processes.
%%%
%%% Each training session gets its own training_proc child.
%%% When training completes, the process terminates and is cleaned up.
%%% @end
-module(training_proc_sup).
-behaviour(supervisor).

-export([start_link/0, start_training/1]).
-export([init/1]).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec start_training(map()) -> {ok, pid()} | {error, term()}.
start_training(Config) ->
    supervisor:start_child(?MODULE, [Config]).

-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => simple_one_for_one,
        intensity => 10,
        period => 10
    },

    ChildSpec = #{
        id => training_proc,
        start => {training_proc, start_link, []},
        restart => temporary,
        type => worker
    },

    {ok, {SupFlags, [ChildSpec]}}.
