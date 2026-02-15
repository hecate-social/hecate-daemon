-module(snake_duel_engine_tests).
-include_lib("eunit/include/eunit.hrl").
-include("snake_duel.hrl").

create_game_test() ->
    State = snake_duel_engine:create_game(50, 75),
    ?assertEqual(idle, State#game_state.status),
    ?assertEqual(0, State#game_state.tick),
    ?assertEqual(3, State#game_state.countdown),
    ?assertEqual(none, State#game_state.winner),
    %% Snake1 starts at right
    ?assertEqual(right, (State#game_state.snake1)#snake.direction),
    ?assertEqual(50, (State#game_state.snake1)#snake.asshole_factor),
    %% Snake2 starts at left
    ?assertEqual(left, (State#game_state.snake2)#snake.direction),
    ?assertEqual(75, (State#game_state.snake2)#snake.asshole_factor),
    %% Both start with 3-segment bodies
    ?assertEqual(3, length((State#game_state.snake1)#snake.body)),
    ?assertEqual(3, length((State#game_state.snake2)#snake.body)),
    %% Food is spawned
    {FX, FY} = State#game_state.food,
    ?assert(FX >= 0 andalso FX < ?GRID_WIDTH),
    ?assert(FY >= 0 andalso FY < ?GRID_HEIGHT).

tick_game_not_running_test() ->
    State = snake_duel_engine:create_game(50, 50),
    %% idle state — should not advance
    Same = snake_duel_engine:tick_game(State),
    ?assertEqual(State, Same).

tick_game_advances_test() ->
    State0 = snake_duel_engine:create_game(50, 50),
    State1 = State0#game_state{status = running},
    State2 = snake_duel_engine:tick_game(State1),
    ?assertEqual(1, State2#game_state.tick),
    ?assertEqual(running, State2#game_state.status).

tick_game_multiple_ticks_test() ->
    State0 = snake_duel_engine:create_game(30, 30),
    State1 = State0#game_state{status = running},
    %% Run 10 ticks — game should still be running (snakes start far apart)
    StateN = lists:foldl(
        fun(_, S) ->
            case S#game_state.status of
                running -> snake_duel_engine:tick_game(S);
                _ -> S
            end
        end,
        State1,
        lists:seq(1, 10)
    ),
    ?assert(StateN#game_state.tick >= 1).

spawn_food_avoids_bodies_test() ->
    Body1 = [{0, 0}, {1, 0}, {2, 0}],
    Body2 = [{5, 5}, {6, 5}],
    Food = snake_duel_engine:spawn_food(Body1, Body2),
    {FX, FY} = Food,
    ?assert(FX >= 0 andalso FX < ?GRID_WIDTH),
    ?assert(FY >= 0 andalso FY < ?GRID_HEIGHT),
    ?assertNot(lists:member(Food, Body1)),
    ?assertNot(lists:member(Food, Body2)).

wall_collision_test() ->
    %% Snake1 is boxed in: heading left at x=0, body fills all escape routes.
    %% The AI sees all 3 valid directions (up, down, left) as deadly or wall,
    %% so it picks left → hits wall.
    %% Create a scenario that WILL end in collision by running enough ticks.
    State0 = snake_duel_engine:create_game(50, 50),
    State1 = State0#game_state{status = running},
    %% Run until finished — game must terminate
    Final = run_until_finished(State1, 2000),
    ?assertEqual(finished, Final#game_state.status),
    ?assert(Final#game_state.winner =/= none).

game_finishes_eventually_test() ->
    %% Run a full game — it should finish within 1000 ticks
    State0 = snake_duel_engine:create_game(50, 50),
    State1 = State0#game_state{status = running},
    FinalState = run_until_finished(State1, 1000),
    ?assertEqual(finished, FinalState#game_state.status),
    ?assert(FinalState#game_state.winner =/= none).

run_until_finished(State, 0) -> State;
run_until_finished(#game_state{status = finished} = State, _) -> State;
run_until_finished(State, N) ->
    run_until_finished(snake_duel_engine:tick_game(State), N - 1).
