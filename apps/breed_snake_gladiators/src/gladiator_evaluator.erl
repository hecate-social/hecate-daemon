%%% @doc Evaluator for snake gladiator — converts game metrics to fitness.
%%%
%%% Fitness formula:
%%%   survival_ticks * 0.1
%%%   + food_eaten * 50.0
%%%   + win_bonus * 200.0
%%%   + draw_bonus * 50.0
%%% @end
-module(gladiator_evaluator).
-behaviour(agent_evaluator).

-include("gladiator.hrl").

-export([name/0, calculate_fitness/1]).

-spec name() -> binary().
name() -> <<"gladiator_fitness">>.

-spec calculate_fitness(map()) -> float().
calculate_fitness(Metrics) ->
    Ticks = maps:get(ticks_survived, Metrics, 0),
    Food = maps:get(food_eaten, Metrics, 0),
    Winner = maps:get(winner, Metrics, none),

    SurvivalScore = Ticks * ?FITNESS_SURVIVAL_WEIGHT,
    FoodScore = Food * ?FITNESS_FOOD_WEIGHT,
    WinScore = case Winner of
        player1 -> ?FITNESS_WIN_BONUS;
        draw -> ?FITNESS_DRAW_BONUS;
        _ -> 0.0
    end,

    SurvivalScore + FoodScore + WinScore.
