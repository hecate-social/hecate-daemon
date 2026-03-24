%%%-------------------------------------------------------------------
%%% @doc Supervisor for listen_game_state workers.
%%% Dynamic simple_one_for_one — one child per remote game joined.
%%% @end
%%%-------------------------------------------------------------------
-module(listen_game_state_sup).
-behaviour(supervisor).

-export([start_link/0, start_listener/1, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec start_listener(map()) -> {ok, pid()} | {error, term()}.
start_listener(Config) ->
    supervisor:start_child(?MODULE, [Config]).

init([]) ->
    SupFlags = #{strategy => simple_one_for_one, intensity => 5, period => 10},
    ChildSpec = #{
        id => listen_game_state,
        start => {listen_game_state, start_link, []},
        restart => temporary,
        type => worker
    },
    {ok, {SupFlags, [ChildSpec]}}.
