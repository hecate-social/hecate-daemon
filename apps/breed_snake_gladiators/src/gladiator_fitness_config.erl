%%% @doc Pure-function module for fitness weight validation, budget, and presets.
%%%
%%% Fitness weights control how gladiators are bred. Each stable can have
%%% custom weights, subject to a tuning budget that limits total deviation
%%% from defaults. High-impact parameters (win_bonus, kill_bonus) cost more
%%% to deviate than low-impact ones (circle_penalty).
%%% @end
-module(gladiator_fitness_config).

-include("gladiator.hrl").

-export([validate_weights/1, tuning_cost/1, within_budget/2, presets/0]).

%% @doc Merge user weights with defaults, clamp each to bounds.
%% Returns {ok, MergedWeights} or {error, Reason}.
-spec validate_weights(map()) -> {ok, map()} | {error, term()}.
validate_weights(UserWeights) when is_map(UserWeights) ->
    Defaults = ?DEFAULT_FITNESS_WEIGHTS,
    Bounds = ?FITNESS_WEIGHT_BOUNDS,
    Merged = maps:fold(
        fun(Key, UserVal, Acc) ->
            case maps:is_key(Key, Defaults) of
                true ->
                    {Min, Max} = maps:get(Key, Bounds),
                    Clamped = clamp(to_float(UserVal), Min, Max),
                    Acc#{Key => Clamped};
                false ->
                    Acc
            end
        end,
        Defaults,
        UserWeights
    ),
    {ok, Merged};
validate_weights(_) ->
    {error, invalid_weights}.

%% @doc Compute total deviation cost from defaults using impact-weighted formula.
%% cost_per_weight = abs(actual - default) / range * impact_factor * 10
-spec tuning_cost(map()) -> float().
tuning_cost(Weights) ->
    Defaults = ?DEFAULT_FITNESS_WEIGHTS,
    Bounds = ?FITNESS_WEIGHT_BOUNDS,
    Impacts = ?FITNESS_WEIGHT_IMPACTS,
    maps:fold(
        fun(Key, Default, Acc) ->
            Actual = maps:get(Key, Weights, Default),
            {Min, Max} = maps:get(Key, Bounds),
            Range = Max - Min,
            Impact = maps:get(Key, Impacts, 1.0),
            Cost = case Range == +0.0 of
                true -> +0.0;
                false -> abs(Actual - Default) / Range * Impact * 10.0
            end,
            Acc + Cost
        end,
        0.0,
        Defaults
    ).

%% @doc Check if weights are within the given tuning budget.
-spec within_budget(map(), float()) -> boolean().
within_budget(Weights, Budget) ->
    tuning_cost(Weights) =< Budget.

%% @doc Named presets for common fitness philosophies.
-spec presets() -> #{atom() => map()}.
presets() ->
    #{
        balanced => ?DEFAULT_FITNESS_WEIGHTS,
        aggressive => #{
            survival_weight   => 0.1,
            food_weight       => 20.0,
            win_bonus         => 400.0,
            draw_bonus        => 50.0,
            kill_bonus        => 250.0,
            wall_kill_bonus   => 150.0,
            proximity_weight  => 0.5,
            circle_penalty    => -0.5
        },
        forager => #{
            survival_weight   => 0.1,
            food_weight       => 150.0,
            win_bonus         => 50.0,
            draw_bonus        => 50.0,
            kill_bonus        => 100.0,
            wall_kill_bonus   => 50.0,
            proximity_weight  => 3.0,
            circle_penalty    => -1.0
        },
        survivor => #{
            survival_weight   => 0.8,
            food_weight       => 50.0,
            win_bonus         => 200.0,
            draw_bonus        => 50.0,
            kill_bonus        => 20.0,
            wall_kill_bonus   => 75.0,
            proximity_weight  => 0.5,
            circle_penalty    => -1.5
        },
        assassin => #{
            survival_weight   => 0.1,
            food_weight       => 0.0,
            win_bonus         => 500.0,
            draw_bonus        => 0.0,
            kill_bonus        => 300.0,
            wall_kill_bonus   => 200.0,
            proximity_weight  => 0.0,
            circle_penalty    => 0.0
        },
        hybrid => #{
            survival_weight   => 0.1,
            food_weight       => 15.0,
            win_bonus         => 500.0,
            draw_bonus        => 25.0,
            kill_bonus        => 250.0,
            wall_kill_bonus   => 150.0,
            proximity_weight  => 0.3,
            circle_penalty    => -0.3
        }
    }.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

clamp(V, Min, _Max) when V < Min -> Min;
clamp(V, _Min, Max) when V > Max -> Max;
clamp(V, _Min, _Max) -> V.

to_float(V) when is_float(V) -> V;
to_float(V) when is_integer(V) -> V + 0.0;
to_float(_) -> 0.0.
