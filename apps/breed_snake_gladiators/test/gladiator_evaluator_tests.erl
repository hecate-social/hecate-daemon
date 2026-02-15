-module(gladiator_evaluator_tests).
-include_lib("eunit/include/eunit.hrl").
-include("gladiator.hrl").

name_test() ->
    ?assertEqual(<<"gladiator_fitness">>, gladiator_evaluator:name()).

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
