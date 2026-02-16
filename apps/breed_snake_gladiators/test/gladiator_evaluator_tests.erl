-module(gladiator_evaluator_tests).
-include_lib("eunit/include/eunit.hrl").
-include("gladiator.hrl").

name_test() ->
    ?assertEqual(<<"gladiator_fitness">>, gladiator_evaluator:name()).

%% Tests with default weights (backward compat — no fitness_weights in metrics)
survival_only_fitness_test() ->
    Metrics = #{ticks_survived => 100, food_eaten => 0, winner => none},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    Expected = 100 * ?FITNESS_SURVIVAL_WEIGHT,
    ?assertEqual(Expected, Fitness).

food_fitness_test() ->
    Metrics = #{ticks_survived => 0, food_eaten => 3, winner => none},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    Expected = 3 * ?FITNESS_FOOD_WEIGHT,
    ?assertEqual(Expected, Fitness).

win_bonus_test() ->
    Metrics = #{ticks_survived => 50, food_eaten => 2, winner => player1},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    Expected = 50 * ?FITNESS_SURVIVAL_WEIGHT
             + 2 * ?FITNESS_FOOD_WEIGHT
             + ?FITNESS_WIN_BONUS,
    ?assertEqual(Expected, Fitness).

draw_bonus_test() ->
    Metrics = #{ticks_survived => 50, food_eaten => 2, winner => draw},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    Expected = 50 * ?FITNESS_SURVIVAL_WEIGHT
             + 2 * ?FITNESS_FOOD_WEIGHT
             + ?FITNESS_DRAW_BONUS,
    ?assertEqual(Expected, Fitness).

loss_no_bonus_test() ->
    Metrics = #{ticks_survived => 50, food_eaten => 2, winner => player2},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    Expected = 50 * ?FITNESS_SURVIVAL_WEIGHT
             + 2 * ?FITNESS_FOOD_WEIGHT,
    ?assertEqual(Expected, Fitness).

%% Tests with custom weights via metrics map
custom_weights_win_test() ->
    CustomW = #{survival_weight => 0.5, food_weight => 100.0,
                win_bonus => 500.0, draw_bonus => 100.0,
                kill_bonus => 200.0, proximity_weight => 1.0,
                circle_penalty => -0.5},
    Metrics = #{ticks_survived => 10, food_eaten => 2,
                winner => player1, opponent_crashed => false,
                food_proximity_delta => 0.0, positions_revisited => 0,
                fitness_weights => CustomW},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    Expected = 10 * 0.5 + 2 * 100.0 + 500.0,
    ?assertEqual(Expected, Fitness).

custom_weights_kill_bonus_test() ->
    CustomW = #{survival_weight => 0.0, food_weight => 0.0,
                win_bonus => 0.0, draw_bonus => 0.0,
                kill_bonus => 999.0, proximity_weight => 0.0,
                circle_penalty => 0.0},
    Metrics = #{ticks_survived => 100, food_eaten => 5,
                winner => player1, opponent_crashed => true,
                food_proximity_delta => 10.0, positions_revisited => 50,
                fitness_weights => CustomW},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    ?assertEqual(999.0, Fitness).

custom_weights_zero_all_test() ->
    CustomW = #{survival_weight => 0.0, food_weight => 0.0,
                win_bonus => 0.0, draw_bonus => 0.0,
                kill_bonus => 0.0, proximity_weight => 0.0,
                circle_penalty => 0.0},
    Metrics = #{ticks_survived => 100, food_eaten => 5,
                winner => player1, opponent_crashed => true,
                food_proximity_delta => 10.0, positions_revisited => 50,
                fitness_weights => CustomW},
    Fitness = gladiator_evaluator:calculate_fitness(Metrics),
    ?assertEqual(0.0, Fitness).
