-module(project_mpong_games_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% ETS store (must start first — creates table)
        #{id => project_mpong_games_store,
          start => {project_mpong_games_store, start_link, []},
          restart => permanent,
          type => worker},
        %% Merged projection: all game lifecycle events -> mpong_games ETS
        #{id => game_lifecycle_to_mpong_games,
          start => {evoq_projection, start_link, [game_lifecycle_to_mpong_games, #{}, #{store_id => mpong_store}]},
          restart => permanent,
          type => worker},
        #{id => champion_registered_v1_to_champions,
          start => {evoq_projection, start_link, [champion_registered_v1_to_champions, #{}, #{store_id => mpong_store}]},
          restart => permanent,
          type => worker}
    ],
    {ok, {SupFlags, Children}}.
