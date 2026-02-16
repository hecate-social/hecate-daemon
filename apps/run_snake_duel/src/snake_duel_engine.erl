%%% @doc Snake Duel game engine — pure functions for game simulation.
%%%
%%% Erlang port of the TypeScript engine.ts.
%%% All functions are side-effect free. The match process (gen_server)
%%% calls tick_game/1 on a timer and broadcasts the resulting state.
%%%
%%% Grid: 30 x 24 cells, 0-indexed.
%%% @end
-module(snake_duel_engine).

-include("snake_duel.hrl").

-export([create_game/2, tick_game/1, tick_step/3, tick_step/4, spawn_food/2, spawn_food/3]).

%%--------------------------------------------------------------------
%% @doc Create initial game state for a match.
%% AF1, AF2 are asshole factors (0-100) for player1 and player2.
%% @end
%%--------------------------------------------------------------------
-spec create_game(non_neg_integer(), non_neg_integer()) -> game_state().
create_game(AF1, AF2) ->
    Snake1Body = [{4,4}, {3,4}, {2,4}],
    Snake2Body = [{25,19}, {26,19}, {27,19}],
    #game_state{
        snake1 = create_snake(Snake1Body, right, AF1),
        snake2 = create_snake(Snake2Body, left, AF2),
        food = spawn_food(Snake1Body, Snake2Body),
        poison_apples = [],
        status = idle,
        winner = none,
        tick = 0,
        countdown = 3
    }.

%%--------------------------------------------------------------------
%% @doc Advance game state by one tick.
%% Returns new state with AI decisions applied, collisions checked,
%% food/poison consumption handled.
%% @end
%%--------------------------------------------------------------------
-spec tick_game(game_state()) -> game_state().
tick_game(#game_state{status = Status} = State) when Status =/= running ->
    State;
tick_game(#game_state{snake1 = S1_0, snake2 = S2_0,
                       food = Food, poison_apples = PA0, walls = Walls} = State) ->
    Dir1 = snake_duel_ai:choose_direction(S1_0, S2_0, Food, PA0, Walls, player1),
    Dir2 = snake_duel_ai:choose_direction(S2_0, S1_0, Food, PA0, Walls, player2),
    Drop1 = snake_duel_ai:should_drop_wall(S1_0, S2_0, Walls, player1),
    Drop2 = snake_duel_ai:should_drop_wall(S2_0, S1_0, Walls, player2),
    tick_step(State, Dir1, Dir2, #{drop_tail_1 => Drop1, drop_tail_2 => Drop2}).

%%--------------------------------------------------------------------
%% @doc Advance game state by one tick with explicit directions.
%% Unlike tick_game/1, callers supply directions instead of the
%% heuristic AI. Poison drops remain heuristic-controlled.
%% @end
%%--------------------------------------------------------------------
-spec tick_step(game_state(), direction(), direction()) -> game_state().
tick_step(State, Dir1, Dir2) ->
    tick_step(State, Dir1, Dir2, #{}).

%%--------------------------------------------------------------------
%% @doc Advance game state with explicit directions and action flags.
%% Actions map may contain:
%%   drop_tail_1 => boolean() — player1 drops tail as wall
%%   drop_tail_2 => boolean() — player2 drops tail as wall
%% @end
%%--------------------------------------------------------------------
-spec tick_step(game_state(), direction(), direction(), map()) -> game_state().
tick_step(#game_state{status = Status} = State, _Dir1, _Dir2, _Actions) when Status =/= running ->
    State;
tick_step(#game_state{tick = Tick0, snake1 = S1_0, snake2 = S2_0,
                       food = Food, poison_apples = PA0,
                       walls = Walls0} = State, Dir1, Dir2, Actions) ->
    Tick = Tick0 + 1,

    %% Decay walls (before movement)
    Walls1 = decay_walls(Walls0),

    %% Move snakes
    S1_1 = move_snake(S1_0, Dir1, Tick),
    S2_1 = move_snake(S2_0, Dir2, Tick),

    %% Check collisions (includes wall tiles)
    case check_collisions(S1_1, S2_1, Walls1) of
        {collision, Loser, Reason} ->
            {S1_2, S2_2} = add_collision_events(S1_1, S2_1, Loser, Reason, Tick),
            Winner = case Loser of
                draw -> draw;
                player1 -> player2;
                player2 -> player1
            end,
            State#game_state{
                snake1 = S1_2, snake2 = S2_2,
                poison_apples = PA0, walls = Walls1, tick = Tick,
                status = finished, winner = Winner
            };
        no_collision ->
            %% Check poison consumption
            {S1_3, PA1} = check_poison_consumption(S1_1, player1, PA0, Tick),
            {S2_3, PA2} = check_poison_consumption(S2_1, player2, PA1, Tick),

            %% Check food consumption
            {S1_4, S2_4, Food1, FoodEaten} = check_food(S1_3, S2_3, Food, Tick),

            %% AI decides poison drops (heuristic-controlled even in tick_step)
            {S1_5, PA3} = maybe_drop_poison(S1_4, S2_4, PA2, player1, Tick),
            {S2_5, PA4} = maybe_drop_poison(S2_4, S1_5, PA3, player2, Tick),

            %% Maybe drop tail as wall (from actions)
            Drop1 = maps:get(drop_tail_1, Actions, false),
            Drop2 = maps:get(drop_tail_2, Actions, false),
            {S1_6, Walls2} = maybe_drop_tail(S1_5, Drop1, player1, Walls1, Tick),
            {S2_6, Walls3} = maybe_drop_tail(S2_5, Drop2, player2, Walls2, Tick),

            %% Spawn new food if eaten (avoid walls too)
            Food2 = case FoodEaten of
                true -> spawn_food(S1_6#snake.body, S2_6#snake.body, Walls3);
                false -> Food1
            end,

            State#game_state{
                snake1 = S1_6, snake2 = S2_6,
                food = Food2, poison_apples = PA4, walls = Walls3, tick = Tick
            }
    end.

%%--------------------------------------------------------------------
%% @doc Spawn food at random position not occupied by any snake.
%% @end
%%--------------------------------------------------------------------
-spec spawn_food([point()], [point()]) -> point().
spawn_food(Body1, Body2) ->
    spawn_food(Body1, Body2, []).

%%--------------------------------------------------------------------
%% @doc Spawn food avoiding snakes and wall tiles.
%% @end
%%--------------------------------------------------------------------
-spec spawn_food([point()], [point()], [wall_tile()]) -> point().
spawn_food(Body1, Body2, Walls) ->
    WallPositions = [W#wall_tile.pos || W <- Walls],
    Occupied = sets:from_list(Body1 ++ Body2 ++ WallPositions),
    spawn_food_loop(Occupied, 0).

spawn_food_loop(_Occupied, 1000) ->
    {?GRID_WIDTH div 2, ?GRID_HEIGHT div 2};
spawn_food_loop(Occupied, Attempts) ->
    X = rand:uniform(?GRID_WIDTH) - 1,
    Y = rand:uniform(?GRID_HEIGHT) - 1,
    case sets:is_element({X, Y}, Occupied) of
        false -> {X, Y};
        true -> spawn_food_loop(Occupied, Attempts + 1)
    end.

%%--------------------------------------------------------------------
%% Internal functions
%%--------------------------------------------------------------------

-spec create_snake([point()], direction(), non_neg_integer()) -> snake().
create_snake(Body, Direction, AF) ->
    #snake{
        body = Body,
        direction = Direction,
        score = 0,
        asshole_factor = AF,
        events = []
    }.

-spec move_snake(snake(), direction(), non_neg_integer()) -> snake().
move_snake(#snake{body = [Head | _] = Body, direction = OldDir, events = Events0} = Snake,
           NewDir, Tick) ->
    NewHead = apply_direction(Head, NewDir),
    NewBody = [NewHead | lists:droplast(Body)],
    Events1 = case NewDir =:= OldDir of
        true -> Events0;
        false ->
            DirBin = atom_to_binary(NewDir),
            add_event(Events0, turn, <<"Turn ", DirBin/binary>>, Tick)
    end,
    Snake#snake{body = NewBody, direction = NewDir, events = Events1}.

-spec apply_direction(point(), direction()) -> point().
apply_direction({X, Y}, up)    -> {X, Y - 1};
apply_direction({X, Y}, down)  -> {X, Y + 1};
apply_direction({X, Y}, left)  -> {X - 1, Y};
apply_direction({X, Y}, right) -> {X + 1, Y}.

-spec check_collisions(snake(), snake(), [wall_tile()]) ->
    {collision, player_tag() | draw, binary()} | no_collision.
check_collisions(#snake{body = [H1 | B1], score = Sc1},
                 #snake{body = [H2 | B2], score = Sc2}, Walls) ->
    H1Wall = is_out_of_bounds(H1),
    H2Wall = is_out_of_bounds(H2),

    %% Head-to-head
    case H1 =:= H2 of
        true -> score_breaker(Sc1, Sc2, <<"Head-to-head collision">>);
        false ->
            %% Both walls (boundary)
            case {H1Wall, H2Wall} of
                {true, true} -> score_breaker(Sc1, Sc2, <<"Both hit walls">>);
                {true, false} -> {collision, player1, <<"Hit wall">>};
                {false, true} -> {collision, player2, <<"Hit wall">>};
                {false, false} ->
                    %% Wall tile collisions (after boundary, before self)
                    WallPositions = sets:from_list([W#wall_tile.pos || W <- Walls]),
                    H1WallTile = sets:is_element(H1, WallPositions),
                    H2WallTile = sets:is_element(H2, WallPositions),
                    case {H1WallTile, H2WallTile} of
                        {true, true} -> score_breaker(Sc1, Sc2, <<"Both hit wall tiles">>);
                        {true, false} -> {collision, player1, <<"Hit wall tile">>};
                        {false, true} -> {collision, player2, <<"Hit wall tile">>};
                        {false, false} ->
                            %% Self collisions
                            H1Self = hits_body(H1, B1),
                            H2Self = hits_body(H2, B2),
                            case {H1Self, H2Self} of
                                {true, true} -> score_breaker(Sc1, Sc2, <<"Both self-collided">>);
                                {true, false} -> {collision, player1, <<"Self collision">>};
                                {false, true} -> {collision, player2, <<"Self collision">>};
                                {false, false} ->
                                    %% Opponent body collisions
                                    H1Opp = hits_body(H1, B2),
                                    H2Opp = hits_body(H2, B1),
                                    case {H1Opp, H2Opp} of
                                        {true, true} -> score_breaker(Sc1, Sc2, <<"Both hit opponent">>);
                                        {true, false} -> {collision, player1, <<"Hit opponent body">>};
                                        {false, true} -> {collision, player2, <<"Hit opponent body">>};
                                        {false, false} -> no_collision
                                    end
                            end
                    end
            end
    end.

-spec score_breaker(integer(), integer(), binary()) ->
    {collision, player_tag() | draw, binary()}.
score_breaker(Sc1, Sc2, Reason) when Sc1 > Sc2 ->
    ScBin = score_suffix(Sc1, Sc2, <<"Blue">>),
    {collision, player2, <<Reason/binary, ScBin/binary>>};
score_breaker(Sc1, Sc2, Reason) when Sc2 > Sc1 ->
    ScBin = score_suffix(Sc2, Sc1, <<"Red">>),
    {collision, player1, <<Reason/binary, ScBin/binary>>};
score_breaker(_Sc1, _Sc2, Reason) ->
    {collision, draw, Reason}.

score_suffix(WinSc, LoseSc, Name) ->
    W = integer_to_binary(WinSc),
    L = integer_to_binary(LoseSc),
    <<" (", Name/binary, " leads ", W/binary, "-", L/binary, ")">>.

-spec is_out_of_bounds(point()) -> boolean().
is_out_of_bounds({X, Y}) ->
    X < 0 orelse X >= ?GRID_WIDTH orelse Y < 0 orelse Y >= ?GRID_HEIGHT.

-spec hits_body(point(), [point()]) -> boolean().
hits_body(Head, Body) ->
    lists:member(Head, Body).

-spec add_collision_events(snake(), snake(), player_tag() | draw, binary(),
                           non_neg_integer()) -> {snake(), snake()}.
add_collision_events(S1, S2, draw, Reason, Tick) ->
    {S1#snake{events = add_event(S1#snake.events, collision, Reason, Tick)},
     S2#snake{events = add_event(S2#snake.events, collision, Reason, Tick)}};
add_collision_events(S1, S2, player1, Reason, Tick) ->
    {S1#snake{events = add_event(S1#snake.events, collision, Reason, Tick)},
     S2#snake{events = add_event(S2#snake.events, win, <<"Victory!">>, Tick)}};
add_collision_events(S1, S2, player2, Reason, Tick) ->
    {S1#snake{events = add_event(S1#snake.events, win, <<"Victory!">>, Tick)},
     S2#snake{events = add_event(S2#snake.events, collision, Reason, Tick)}}.

-spec check_poison_consumption(snake(), player_tag(), [poison_apple()],
                                non_neg_integer()) -> {snake(), [poison_apple()]}.
check_poison_consumption(#snake{body = [Head | _]} = Snake, Tag, PoisonApples, Tick) ->
    case find_poison_at(Head, PoisonApples) of
        {found, #poison_apple{owner = Owner}, Rest} ->
            OwnPoison = Owner =:= Tag,
            NewScore = max(0, Snake#snake.score - 1),
            NewBody = case length(Snake#snake.body) > 1 of
                true -> lists:droplast(Snake#snake.body);
                false -> Snake#snake.body
            end,
            ScBin = integer_to_binary(NewScore),
            Msg = case OwnPoison of
                true -> <<"Ate own poison! (", ScBin/binary, ")">>;
                false -> <<"Poisoned! (", ScBin/binary, ")">>
            end,
            Events = add_event(Snake#snake.events, poison_eat, Msg, Tick),
            {Snake#snake{score = NewScore, body = NewBody, events = Events}, Rest};
        not_found ->
            {Snake, PoisonApples}
    end.

-spec find_poison_at(point(), [poison_apple()]) ->
    {found, poison_apple(), [poison_apple()]} | not_found.
find_poison_at(_Pos, []) -> not_found;
find_poison_at(Pos, [#poison_apple{pos = Pos} = PA | Rest]) ->
    {found, PA, Rest};
find_poison_at(Pos, [PA | Rest]) ->
    case find_poison_at(Pos, Rest) of
        {found, Found, Remaining} -> {found, Found, [PA | Remaining]};
        not_found -> not_found
    end.

-spec check_food(snake(), snake(), point(), non_neg_integer()) ->
    {snake(), snake(), point(), boolean()}.
check_food(#snake{body = [H1 | _]} = S1, #snake{body = [H2 | _]} = S2, Food, Tick) ->
    Ate1 = H1 =:= Food,
    Ate2 = H2 =:= Food,
    S1_1 = case Ate1 of
        true ->
            NewScore = S1#snake.score + 1,
            ScBin = integer_to_binary(NewScore),
            S1#snake{
                score = NewScore,
                body = S1#snake.body ++ [lists:last(S1#snake.body)],
                events = add_event(S1#snake.events, food,
                    <<"Ate food (", ScBin/binary, ")">>, Tick)
            };
        false -> S1
    end,
    S2_1 = case Ate2 of
        true ->
            NewScore2 = S2#snake.score + 1,
            ScBin2 = integer_to_binary(NewScore2),
            S2#snake{
                score = NewScore2,
                body = S2#snake.body ++ [lists:last(S2#snake.body)],
                events = add_event(S2#snake.events, food,
                    <<"Ate food (", ScBin2/binary, ")">>, Tick)
            };
        false -> S2
    end,
    {S1_1, S2_1, Food, Ate1 orelse Ate2}.

-spec maybe_drop_poison(snake(), snake(), [poison_apple()], player_tag(),
                         non_neg_integer()) -> {snake(), [poison_apple()]}.
maybe_drop_poison(Snake, Opponent, PoisonApples, OwnTag, Tick) ->
    case snake_duel_ai:should_drop_poison(Snake, Opponent, PoisonApples, OwnTag) of
        true ->
            DropPos = lists:last(Snake#snake.body),
            NewPA = [#poison_apple{pos = DropPos, owner = OwnTag} | PoisonApples],
            NewScore = Snake#snake.score - 1,
            NewBody = case length(Snake#snake.body) > 1 of
                true -> lists:droplast(Snake#snake.body);
                false -> Snake#snake.body
            end,
            ScBin = integer_to_binary(NewScore),
            Events = add_event(Snake#snake.events, poison_drop,
                <<"Dropped poison (", ScBin/binary, ")">>, Tick),
            {Snake#snake{score = NewScore, body = NewBody, events = Events}, NewPA};
        false ->
            {Snake, PoisonApples}
    end.

%%--------------------------------------------------------------------
%% Wall functions
%%--------------------------------------------------------------------

-spec decay_walls([wall_tile()]) -> [wall_tile()].
decay_walls(Walls) ->
    [W#wall_tile{ttl = W#wall_tile.ttl - 1} || W <- Walls, W#wall_tile.ttl > 1].

-spec maybe_drop_tail(snake(), boolean(), player_tag(), [wall_tile()],
                       non_neg_integer()) -> {snake(), [wall_tile()]}.
maybe_drop_tail(Snake, false, _Tag, Walls, _Tick) ->
    {Snake, Walls};
maybe_drop_tail(#snake{body = Body} = Snake, true, _Tag, Walls, _Tick) when length(Body) < 6 ->
    {Snake, Walls};
maybe_drop_tail(#snake{body = Body, events = Events0} = Snake, true, Tag, Walls, Tick) ->
    OwnWallCount = length([1 || #wall_tile{owner = O} <- Walls, O =:= Tag]),
    case OwnWallCount >= 3 of
        true ->
            {Snake, Walls};
        false ->
            DropPos = lists:last(Body),
            %% Don't drop on an existing wall tile
            Occupied = sets:from_list([W#wall_tile.pos || W <- Walls]),
            case sets:is_element(DropPos, Occupied) of
                true ->
                    {Snake, Walls};
                false ->
                    NewBody = lists:droplast(Body),
                    NewWall = #wall_tile{pos = DropPos, owner = Tag, ttl = ?WALL_TTL},
                    Events1 = add_event(Events0, wall_drop, <<"Dropped wall">>, Tick),
                    {Snake#snake{body = NewBody, events = Events1}, [NewWall | Walls]}
            end
    end.

-spec add_event([game_event()], atom(), binary(), non_neg_integer()) -> [game_event()].
add_event(Events, Type, Value, Tick) ->
    NewEvent = #game_event{type = Type, value = Value, tick = Tick},
    lists:sublist([NewEvent | Events], 10).
