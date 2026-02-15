-module(snake_duel_ai_tests).
-include_lib("eunit/include/eunit.hrl").
-include("snake_duel.hrl").

choose_direction_avoids_reverse_test() ->
    Snake = #snake{body = [{5, 5}, {4, 5}, {3, 5}], direction = right,
                   score = 0, asshole_factor = 50, events = []},
    Opponent = #snake{body = [{20, 20}, {21, 20}, {22, 20}], direction = left,
                      score = 0, asshole_factor = 50, events = []},
    Food = {10, 10},
    Dir = snake_duel_ai:choose_direction(Snake, Opponent, Food, [], player1),
    %% Should never go left (reverse of right)
    ?assertNotEqual(left, Dir).

choose_direction_avoids_walls_test() ->
    %% Snake near top-left corner, heading up
    Snake = #snake{body = [{1, 1}, {1, 2}, {1, 3}], direction = up,
                   score = 0, asshole_factor = 0, events = []},
    Opponent = #snake{body = [{20, 20}, {21, 20}, {22, 20}], direction = left,
                      score = 0, asshole_factor = 0, events = []},
    Food = {15, 15},
    Dir = snake_duel_ai:choose_direction(Snake, Opponent, Food, [], player1),
    %% Should pick a valid direction (not reverse of up = down)
    ?assertNotEqual(down, Dir).

should_drop_poison_gentleman_never_test() ->
    Snake = #snake{body = lists:duplicate(6, {5, 5}), direction = right,
                   score = 5, asshole_factor = 10, events = []},
    Opponent = #snake{body = [{10, 10}, {11, 10}], direction = left,
                      score = 3, asshole_factor = 50, events = []},
    %% Gentleman (AF=10) should never drop poison
    ?assertEqual(false, snake_duel_ai:should_drop_poison(Snake, Opponent, [], player1)).

should_drop_poison_too_short_test() ->
    Snake = #snake{body = [{5, 5}, {6, 5}, {7, 5}], direction = right,
                   score = 5, asshole_factor = 100, events = []},
    Opponent = #snake{body = [{10, 10}, {11, 10}], direction = left,
                      score = 3, asshole_factor = 50, events = []},
    %% Body too short (3 <= 5), should not drop
    ?assertEqual(false, snake_duel_ai:should_drop_poison(Snake, Opponent, [], player1)).

should_drop_poison_low_score_test() ->
    Snake = #snake{body = lists:duplicate(6, {5, 5}), direction = right,
                   score = 2, asshole_factor = 100, events = []},
    Opponent = #snake{body = [{10, 10}, {11, 10}], direction = left,
                      score = 3, asshole_factor = 50, events = []},
    %% Score < 3, should not drop
    ?assertEqual(false, snake_duel_ai:should_drop_poison(Snake, Opponent, [], player1)).

should_drop_poison_max_on_field_test() ->
    Snake = #snake{body = lists:duplicate(8, {5, 5}), direction = right,
                   score = 10, asshole_factor = 100, events = []},
    Opponent = #snake{body = [{10, 10}, {11, 10}], direction = left,
                      score = 3, asshole_factor = 50, events = []},
    PA = [#poison_apple{pos = {3, 3}, owner = player1},
          #poison_apple{pos = {4, 4}, owner = player1}],
    %% Already 2 own poison apples, should not drop more
    ?assertEqual(false, snake_duel_ai:should_drop_poison(Snake, Opponent, PA, player1)).
