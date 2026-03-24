%%%-------------------------------------------------------------------
%%% @doc Top-level supervisor for MPong game lifecycle.
%%% @end
%%%-------------------------------------------------------------------
-module(guide_mpong_game_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id => run_game_engine_sup,
          start => {run_game_engine_sup, start_link, []},
          restart => permanent,
          type => supervisor},
        #{id => listen_game_state_sup,
          start => {listen_game_state_sup, start_link, []},
          restart => permanent,
          type => supervisor},
        #{id => mpong_lobby_seeker,
          start => {mpong_lobby_seeker, start_link, []},
          restart => permanent,
          type => worker}
    ],
    {ok, {SupFlags, Children}}.
