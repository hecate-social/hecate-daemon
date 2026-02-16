%%% @doc Evaluator for snake gladiator — converts game metrics to fitness.
%%%
%%% Fitness formula:
%%%   survival_ticks * 0.1
%%%   + food_eaten * 50.0
%%%   + win_bonus (200.0 for win, 50.0 for draw)
%%%   + kill_bonus (100.0 when opponent crashed into wall/body)
%%%   + food_proximity_delta * 0.5 (reward getting closer to food)
%%%   + positions_revisited * -0.2 (penalize going in circles)
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
    OpponentCrashed = maps:get(opponent_crashed, Metrics, false),
    ProximityDelta = maps:get(food_proximity_delta, Metrics, 0.0),
    Revisited = maps:get(positions_revisited, Metrics, 0),

    SurvivalScore = Ticks * ?FITNESS_SURVIVAL_WEIGHT,
    FoodScore = Food * ?FITNESS_FOOD_WEIGHT,

    WinScore = case Winner of
        player1 -> ?FITNESS_WIN_BONUS;
        draw -> ?FITNESS_DRAW_BONUS;
        _ -> 0.0
    end,

    %% Extra bonus for winning by making the opponent crash
    KillScore = case OpponentCrashed of
        true -> ?FITNESS_KILL_BONUS;
        false -> 0.0
    end,

    %% Reward net movement toward food (positive delta = got closer)
    ProximityScore = ProximityDelta * ?FITNESS_PROXIMITY_WEIGHT,

    %% Penalize revisiting positions (going in circles)
    CirclePenalty = Revisited * ?FITNESS_CIRCLE_PENALTY,

    max(0.0, SurvivalScore + FoodScore + WinScore + KillScore +
             ProximityScore + CirclePenalty).
