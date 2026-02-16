-module(gladiator_fitness_config_tests).
-include_lib("eunit/include/eunit.hrl").
-include("gladiator.hrl").

validate_defaults_test() ->
    {ok, Weights} = gladiator_fitness_config:validate_weights(#{}),
    ?assertEqual(?DEFAULT_FITNESS_WEIGHTS, Weights).

validate_partial_merge_test() ->
    {ok, Weights} = gladiator_fitness_config:validate_weights(#{kill_bonus => 250.0}),
    ?assertEqual(250.0, maps:get(kill_bonus, Weights)),
    %% Other values are defaults
    ?assertEqual(0.1, maps:get(survival_weight, Weights)).

validate_clamps_to_bounds_test() ->
    {ok, Weights} = gladiator_fitness_config:validate_weights(#{
        kill_bonus => 999.0,     %% max is 300
        survival_weight => -5.0  %% min is 0.0
    }),
    ?assertEqual(300.0, maps:get(kill_bonus, Weights)),
    ?assertEqual(0.0, maps:get(survival_weight, Weights)).

validate_ignores_unknown_keys_test() ->
    {ok, Weights} = gladiator_fitness_config:validate_weights(#{
        unknown_key => 42.0,
        food_weight => 100.0
    }),
    ?assertEqual(false, maps:is_key(unknown_key, Weights)),
    ?assertEqual(100.0, maps:get(food_weight, Weights)).

validate_invalid_input_test() ->
    ?assertEqual({error, invalid_weights}, gladiator_fitness_config:validate_weights(not_a_map)).

tuning_cost_defaults_zero_test() ->
    Cost = gladiator_fitness_config:tuning_cost(?DEFAULT_FITNESS_WEIGHTS),
    ?assertEqual(0.0, Cost).

tuning_cost_positive_for_deviation_test() ->
    Defaults = ?DEFAULT_FITNESS_WEIGHTS,
    Weights = Defaults#{kill_bonus => 250.0},
    Cost = gladiator_fitness_config:tuning_cost(Weights),
    ?assert(Cost > 0.0).

within_budget_defaults_test() ->
    ?assert(gladiator_fitness_config:within_budget(?DEFAULT_FITNESS_WEIGHTS, 100.0)).

within_budget_extreme_deviation_test() ->
    %% Max out everything — should exceed budget
    Extreme = #{
        survival_weight   => 1.0,
        food_weight       => 200.0,
        win_bonus         => 500.0,
        draw_bonus        => 200.0,
        kill_bonus        => 300.0,
        proximity_weight  => 5.0,
        circle_penalty    => -2.0
    },
    ?assertNot(gladiator_fitness_config:within_budget(Extreme, 50.0)).

presets_all_valid_test() ->
    Presets = gladiator_fitness_config:presets(),
    ?assert(maps:is_key(balanced, Presets)),
    ?assert(maps:is_key(aggressive, Presets)),
    ?assert(maps:is_key(forager, Presets)),
    ?assert(maps:is_key(survivor, Presets)),
    ?assert(maps:is_key(assassin, Presets)),
    %% All presets should validate
    maps:foreach(
        fun(_Name, Weights) ->
            {ok, _} = gladiator_fitness_config:validate_weights(Weights)
        end,
        Presets
    ).

presets_balanced_is_default_test() ->
    #{balanced := Balanced} = gladiator_fitness_config:presets(),
    ?assertEqual(?DEFAULT_FITNESS_WEIGHTS, Balanced).
