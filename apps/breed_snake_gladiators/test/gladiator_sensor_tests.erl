-module(gladiator_sensor_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("run_snake_duel/include/snake_duel.hrl").
-include("gladiator.hrl").

input_count_test() ->
    ?assertEqual(?GLADIATOR_INPUTS, gladiator_sensor:input_count()).

name_test() ->
    ?assertEqual(<<"gladiator_vision">>, gladiator_sensor:name()).

read_returns_correct_count_test() ->
    Game = snake_duel_engine:create_game(0, 50),
    Game1 = Game#game_state{status = running, countdown = 0},
    AgentState = #{player => player1},
    EnvState = #{game => Game1},
    Inputs = gladiator_sensor:read(AgentState, EnvState),
    ?assertEqual(?GLADIATOR_INPUTS, length(Inputs)),
    %% All values should be numbers
    lists:foreach(fun(V) -> ?assert(is_number(V)) end, Inputs).

danger_detects_wall_test() ->
    %% Snake1 at top-left corner heading up — danger up should be 1.0
    Snake1 = #snake{body = [{0, 0}, {1, 0}, {2, 0}],
                    direction = up, score = 0, asshole_factor = 0, events = []},
    Snake2 = #snake{body = [{25, 19}, {26, 19}, {27, 19}],
                    direction = left, score = 0, asshole_factor = 50, events = []},
    Game = #game_state{snake1 = Snake1, snake2 = Snake2,
                       food = {15, 12}, poison_apples = [],
                       status = running, winner = none, tick = 0, countdown = 0},
    Inputs = gladiator_sensor:read(#{player => player1}, #{game => Game}),
    %% Index 5 = DangerUp (0-indexed: 4th element)
    DangerUp = lists:nth(5, Inputs),
    ?assertEqual(1.0, DangerUp),
    %% DangerLeft should also be 1.0 (wall at x=-1)
    DangerLeft = lists:nth(7, Inputs),
    ?assertEqual(1.0, DangerLeft).

direction_one_hot_test() ->
    Snake1 = #snake{body = [{4, 4}, {3, 4}, {2, 4}],
                    direction = right, score = 0, asshole_factor = 0, events = []},
    Snake2 = #snake{body = [{25, 19}, {26, 19}, {27, 19}],
                    direction = left, score = 0, asshole_factor = 50, events = []},
    Game = #game_state{snake1 = Snake1, snake2 = Snake2,
                       food = {15, 12}, poison_apples = [],
                       status = running, winner = none, tick = 0, countdown = 0},
    Inputs = gladiator_sensor:read(#{player => player1}, #{game => Game}),
    %% Indices 11-14 = direction one-hot [up, down, left, right]
    DirUp = lists:nth(11, Inputs),
    DirDown = lists:nth(12, Inputs),
    DirLeft = lists:nth(13, Inputs),
    DirRight = lists:nth(14, Inputs),
    ?assertEqual(0.0, DirUp),
    ?assertEqual(0.0, DirDown),
    ?assertEqual(0.0, DirLeft),
    ?assertEqual(1.0, DirRight).
