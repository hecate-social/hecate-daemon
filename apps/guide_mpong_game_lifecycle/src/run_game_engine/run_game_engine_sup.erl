%%%-------------------------------------------------------------------
%%% @doc Supervisor for dynamic game engine processes.
%%%
%%% Uses simple_one_for_one to start/stop game engines on demand.
%%% Each game engine is a transient worker that dies when the game ends.
%%% @end
%%%-------------------------------------------------------------------
-module(run_game_engine_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).
-export([start_engine/1, stop_engine/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => simple_one_for_one,
        intensity => 10,
        period => 10
    },
    ChildSpec = #{
        id => mpong_game_engine,
        start => {mpong_game_engine, start_link, []},
        restart => temporary,
        type => worker
    },
    {ok, {SupFlags, [ChildSpec]}}.

-spec start_engine(map()) -> {ok, pid()} | {error, term()}.
start_engine(GameConfig) ->
    supervisor:start_child(?MODULE, [GameConfig]).

-spec stop_engine(pid()) -> ok.
stop_engine(Pid) ->
    supervisor:terminate_child(?MODULE, Pid).
