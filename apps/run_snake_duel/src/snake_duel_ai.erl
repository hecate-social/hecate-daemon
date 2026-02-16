%%% @doc Snake Duel AI — heuristic direction scoring.
%%%
%%% Erlang port of ai.ts. Pure functions.
%%% Each snake evaluates all valid directions and picks the best one.
%%% The asshole_factor (0-100) controls aggressive behavior:
%%%   0-19: Gentleman, 20-39: Chill, 40-59: Competitive,
%%%   60-79: Aggressive, 80-100: Total Jerk.
%%% @end
-module(snake_duel_ai).

-include("snake_duel.hrl").

-export([choose_direction/5, choose_direction/6, should_drop_poison/4, should_drop_wall/4]).

-define(DIRECTIONS, [up, down, left, right]).

%%--------------------------------------------------------------------
%% @doc Choose the best direction for a snake (backward compat, no walls).
%% @end
%%--------------------------------------------------------------------
-spec choose_direction(snake(), snake(), point(), [poison_apple()], player_tag()) ->
    direction().
choose_direction(Snake, Opponent, Food, PoisonApples, OwnTag) ->
    choose_direction(Snake, Opponent, Food, PoisonApples, [], OwnTag).

%%--------------------------------------------------------------------
%% @doc Choose the best direction for a snake, with wall awareness.
%% Filters out reverse direction, scores all valid options, returns best.
%% @end
%%--------------------------------------------------------------------
-spec choose_direction(snake(), snake(), point(), [poison_apple()], [wall_tile()], player_tag()) ->
    direction().
choose_direction(#snake{direction = CurDir} = Snake, Opponent, Food, PoisonApples, Walls, OwnTag) ->
    Opposite = opposite(CurDir),
    ValidDirs = [D || D <- ?DIRECTIONS, D =/= Opposite],
    WallPositions = [W#wall_tile.pos || W <- Walls],
    Obstacles = build_obstacle_set(tl(Snake#snake.body), Opponent#snake.body ++ WallPositions),
    OwnPoisons = poison_set(PoisonApples, OwnTag, same),
    OppPoisons = poison_set(PoisonApples, OwnTag, other),

    Scored = [{D, score_direction(D, Snake, Opponent, Food, Obstacles,
                                   OwnPoisons, OppPoisons)} || D <- ValidDirs],
    {BestDir, _} = lists:foldl(
        fun({D, S}, {_BD, BS}) when S > BS -> {D, S};
           (_, Acc) -> Acc
        end,
        {CurDir, -99999},
        Scored
    ),
    BestDir.

%%--------------------------------------------------------------------
%% @doc Decide whether to drop a poison apple this tick.
%% @end
%%--------------------------------------------------------------------
-spec should_drop_poison(snake(), snake(), [poison_apple()], player_tag()) ->
    boolean().
should_drop_poison(#snake{score = Score, body = Body, asshole_factor = AF}, Opponent, PoisonApples, OwnTag) ->
    case Score < 3 orelse length(Body) =< 5 of
        true -> false;
        false ->
            AFn = AF / 100,
            case AFn < 0.2 of
                true -> false;
                false ->
                    BaseChance = AFn * 0.03,
                    OppHead = hd(Opponent#snake.body),
                    Tail = lists:last(Body),
                    Dist = manhattan(Tail, OppHead),
                    ProxBonus = case Dist < 5 of
                        true -> AFn * 0.02;
                        false -> 0
                    end,
                    OwnCount = length([1 || #poison_apple{owner = O} <- PoisonApples, O =:= OwnTag]),
                    case OwnCount >= 2 of
                        true -> false;
                        false -> rand:uniform() < BaseChance + ProxBonus
                    end
            end
    end.

%%--------------------------------------------------------------------
%% @doc Decide whether to drop a wall tile (tail segment) this tick.
%% Requires AF >= 30, body >= 6, max 3 own walls on field.
%% @end
%%--------------------------------------------------------------------
-spec should_drop_wall(snake(), snake(), [wall_tile()], player_tag()) ->
    boolean().
should_drop_wall(#snake{body = Body, asshole_factor = AF}, Opponent, Walls, OwnTag) ->
    case AF < 30 orelse length(Body) < 6 of
        true -> false;
        false ->
            OwnCount = length([1 || #wall_tile{owner = O} <- Walls, O =:= OwnTag]),
            case OwnCount >= 3 of
                true -> false;
                false ->
                    AFn = AF / 100,
                    BaseChance = AFn * 0.02,
                    OppHead = hd(Opponent#snake.body),
                    Tail = lists:last(Body),
                    Dist = manhattan(Tail, OppHead),
                    ProxBonus = case Dist < 6 of
                        true -> AFn * 0.015;
                        false -> 0
                    end,
                    rand:uniform() < BaseChance + ProxBonus
            end
    end.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

-spec score_direction(direction(), snake(), snake(), point(),
                      sets:set(point()), sets:set(point()), sets:set(point())) ->
    float().
score_direction(Dir, Snake, Opponent, Food, Obstacles, OwnPoisons, OppPoisons) ->
    Head = hd(Snake#snake.body),
    NewHead = apply_dir(Head, Dir),
    AF = Snake#snake.asshole_factor / 100,

    case is_deadly(NewHead, Obstacles) of
        true -> -1000.0;
        false ->
            Score0 = 0.0,

            %% Avoid opponent's poison
            Score1 = case sets:is_element(NewHead, OppPoisons) of
                true -> Score0 - 200;
                false -> Score0
            end,

            %% Avoid own poison (less penalty)
            Score2 = case sets:is_element(NewHead, OwnPoisons) of
                true -> Score1 - 80;
                false -> Score1
            end,

            %% Reachable space (flood fill capped at 50)
            Reachable = flood_fill(NewHead, Obstacles, 50),
            Score3 = Score2 + Reachable * 2,

            %% Food attraction
            OldFoodDist = manhattan(Head, Food),
            NewFoodDist = manhattan(NewHead, Food),
            Score4 = Score3 + (OldFoodDist - NewFoodDist) * 15,

            %% Wall avoidance
            {NX, NY} = NewHead,
            Score5 = case NX < 2 orelse NX >= ?GRID_WIDTH - 2 orelse
                          NY < 2 orelse NY >= ?GRID_HEIGHT - 2 of
                true -> Score4 - 5;
                false -> Score4
            end,

            %% Escape routes: count safe neighbors
            SafeNeighbors = length([D || D <- ?DIRECTIONS,
                                         not is_deadly(apply_dir(NewHead, D), Obstacles)]),
            Score6 = Score5 + SafeNeighbors * 5,

            %% Trap detection
            Score7 = case Reachable < length(Snake#snake.body) + 3 of
                true -> Score6 - 100;
                false -> Score6
            end,

            %% --- Asshole factor bonuses ---
            OppHead = hd(Opponent#snake.body),

            %% Space cutoff
            OppObsWithout = build_obstacle_set(tl(Opponent#snake.body), Snake#snake.body),
            OppSpaceNow = flood_fill(OppHead, OppObsWithout, 50),
            NewSnakeBody = [NewHead | lists:droplast(Snake#snake.body)],
            OppObsWith = build_obstacle_set(tl(Opponent#snake.body), NewSnakeBody),
            OppSpaceAfter = flood_fill(OppHead, OppObsWith, 50),
            SpaceCutoff = OppSpaceNow - OppSpaceAfter,
            Score8 = case SpaceCutoff > 0 of
                true -> Score7 + SpaceCutoff * 3 * AF;
                false -> Score7
            end,

            %% Food stealing
            OppFoodDist = manhattan(OppHead, Food),
            Score9 = case NewFoodDist < OppFoodDist of
                true -> Score8 + 10 * AF;
                false -> Score8
            end,

            %% Body blocking
            OppSafeAfter = length([D || D <- ?DIRECTIONS,
                                        not is_deadly(apply_dir(OppHead, D), OppObsWith)]),
            OppSafeNow = length([D || D <- ?DIRECTIONS,
                                      not is_deadly(apply_dir(OppHead, D), OppObsWithout)]),
            BlockedRoutes = OppSafeNow - OppSafeAfter,
            Score10 = case BlockedRoutes > 0 of
                true -> Score9 + BlockedRoutes * 8 * AF;
                false -> Score9
            end,

            %% Lure opponent toward own poison
            Score11 = sets:fold(
                fun(PoisonPos, Acc) ->
                    case manhattan(OppHead, PoisonPos) < 8 of
                        true -> Acc + AF * 5;
                        false -> Acc
                    end
                end,
                Score10,
                OwnPoisons
            ),

            %% Head-to-head proximity penalty
            HeadDist = manhattan(NewHead, OppHead),
            Score12 = case HeadDist =< 2 of
                true -> Score11 - (50 - AF * 25);
                false -> Score11
            end,

            %% Random jitter
            Jitter = (rand:uniform() - 0.5) * (50 + AF * 12.5),
            Score13 = Score12 + Jitter,

            %% Risky aggression
            Score14 = case rand:uniform() < (5 + AF * 10) / 100 of
                true -> Score13 + rand:uniform() * 30;
                false -> Score13
            end,

            Score14
    end.

-spec opposite(direction()) -> direction().
opposite(up) -> down;
opposite(down) -> up;
opposite(left) -> right;
opposite(right) -> left.

-spec apply_dir(point(), direction()) -> point().
apply_dir({X, Y}, up)    -> {X, Y - 1};
apply_dir({X, Y}, down)  -> {X, Y + 1};
apply_dir({X, Y}, left)  -> {X - 1, Y};
apply_dir({X, Y}, right) -> {X + 1, Y}.

-spec is_deadly(point(), sets:set(point())) -> boolean().
is_deadly({X, Y}, _Obstacles) when X < 0; X >= ?GRID_WIDTH;
                                    Y < 0; Y >= ?GRID_HEIGHT ->
    true;
is_deadly(Point, Obstacles) ->
    sets:is_element(Point, Obstacles).

-spec build_obstacle_set([point()], [point()]) -> sets:set(point()).
build_obstacle_set(Body1, Body2) ->
    sets:from_list(Body1 ++ Body2).

-spec poison_set([poison_apple()], player_tag(), same | other) -> sets:set(point()).
poison_set(PoisonApples, OwnTag, same) ->
    sets:from_list([Pos || #poison_apple{pos = Pos, owner = O} <- PoisonApples, O =:= OwnTag]);
poison_set(PoisonApples, OwnTag, other) ->
    sets:from_list([Pos || #poison_apple{pos = Pos, owner = O} <- PoisonApples, O =/= OwnTag]).

-spec flood_fill(point(), sets:set(point()), non_neg_integer()) -> non_neg_integer().
flood_fill(Start, Obstacles, Max) ->
    case is_deadly(Start, Obstacles) of
        true -> 0;
        false ->
            Visited = sets:from_list([Start]),
            flood_fill_loop(queue:from_list([Start]), Obstacles, Visited, 0, Max)
    end.

flood_fill_loop(_Queue, _Obstacles, _Visited, Count, Max) when Count >= Max ->
    Count;
flood_fill_loop(Queue, Obstacles, Visited, Count, Max) ->
    case queue:out(Queue) of
        {empty, _} -> Count;
        {{value, Current}, Queue1} ->
            Neighbors = [apply_dir(Current, D) || D <- ?DIRECTIONS],
            {Queue2, Visited2, _Added} = lists:foldl(
                fun(N, {Q, V, A}) ->
                    case not is_deadly(N, Obstacles) andalso not sets:is_element(N, V) of
                        true -> {queue:in(N, Q), sets:add_element(N, V), A + 1};
                        false -> {Q, V, A}
                    end
                end,
                {Queue1, Visited, 0},
                Neighbors
            ),
            NewCount = Count + 1,
            case NewCount >= Max of
                true -> NewCount;
                false -> flood_fill_loop(Queue2, Obstacles, Visited2, NewCount, Max)
            end
    end.

-spec manhattan(point(), point()) -> non_neg_integer().
manhattan({X1, Y1}, {X2, Y2}) ->
    abs(X1 - X2) + abs(Y1 - Y2).
