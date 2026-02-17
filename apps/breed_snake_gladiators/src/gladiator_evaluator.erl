%%% @doc Evaluator for snake gladiator — converts game metrics to fitness.
%%%
%%% Fitness formula uses configurable weights (from metrics map or defaults):
%%%   survival_ticks * survival_weight
%%%   + food_eaten * food_weight
%%%   + win_bonus (for win), draw_bonus (for draw)
%%%   + kill_bonus (when opponent crashed into wall/body)
%%%   + food_proximity_delta * proximity_weight
%%%   + positions_revisited * circle_penalty
%%% @end
-module(gladiator_evaluator).
-behaviour(agent_evaluator).

-include("gladiator.hrl").

-export([name/0, calculate_fitness/1]).

-spec name() -> binary().
name() -> <<"gladiator_fitness">>.

-spec calculate_fitness(map()) -> float().
calculate_fitness(Metrics) ->
    W = maps:get(fitness_weights, Metrics, ?DEFAULT_FITNESS_WEIGHTS),
    SurvivalW  = maps:get(survival_weight, W, ?FITNESS_SURVIVAL_WEIGHT),
    FoodW      = maps:get(food_weight, W, ?FITNESS_FOOD_WEIGHT),
    WinB       = maps:get(win_bonus, W, ?FITNESS_WIN_BONUS),
    DrawB      = maps:get(draw_bonus, W, ?FITNESS_DRAW_BONUS),
    KillB      = maps:get(kill_bonus, W, ?FITNESS_KILL_BONUS),
    ProximityW = maps:get(proximity_weight, W, ?FITNESS_PROXIMITY_WEIGHT),
    CircleP    = maps:get(circle_penalty, W, ?FITNESS_CIRCLE_PENALTY),
    WallKillB  = maps:get(wall_kill_bonus, W, 75.0),

    Ticks = maps:get(ticks_survived, Metrics, 0),
    Food = maps:get(food_eaten, Metrics, 0),
    Winner = maps:get(winner, Metrics, none),
    OpponentCrashed = maps:get(opponent_crashed, Metrics, false),
    ProximityDelta = maps:get(food_proximity_delta, Metrics, 0.0),
    UniquePositions = maps:get(unique_positions, Metrics, max(1, Ticks)),
    WallKills = maps:get(wall_kills, Metrics, 0),

    SurvivalScore = Ticks * SurvivalW,
    FoodScore = Food * FoodW,

    WinScore = case Winner of
        player1 -> WinB;
        draw -> DrawB;
        _ -> 0.0
    end,

    %% Extra bonus for winning by making the opponent crash
    KillScore = case OpponentCrashed of
        true -> KillB;
        false -> 0.0
    end,

    %% Bonus for kills via wall tiles
    WallKillScore = WallKills * WallKillB,

    %% Reward net movement toward food (positive delta = got closer)
    ProximityScore = ProximityDelta * ProximityW,

    %% Circle penalty based on exploration ratio.
    %% CircleRatio: 0.0 = all moves to new cells, 1.0 = stuck on same cell.
    %% Scaled to [0, 100] range so it competes with (not dwarfs) food/win rewards.
    %% Old approach counted raw revisits which grew unboundedly with game length,
    %% overwhelming all positive signals on a finite grid.
    CircleRatio = 1.0 - (UniquePositions / max(1.0, Ticks + 0.0)),
    CirclePenalty = CircleRatio * 100.0 * CircleP,

    %% No max(0.0, ...) clamp — negative fitness preserves gradient among
    %% bad performers so evolution can distinguish "slightly circling" from
    %% "wildly circling." Tournament selection handles negative values fine.
    SurvivalScore + FoodScore + WinScore + KillScore +
        WallKillScore + ProximityScore + CirclePenalty.
