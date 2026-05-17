%%%-------------------------------------------------------------------
%%% @doc Desk supervisor for auto_host_demo_loop. Conditionally started
%%% by guide_mpong_game_lifecycle_sup only when `{hecate,
%%% mpong_auto_host}' = true. See `auto_host_demo_loop'.
%%% @end
%%%-------------------------------------------------------------------
-module(auto_host_demo_loop_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Children = [
        #{id => auto_host_demo_loop,
          start => {auto_host_demo_loop, start_link, []},
          restart => permanent,
          type => worker}
    ],
    {ok, {SupFlags, Children}}.
