%%% @doc Sensor for snake gladiator — reads game state into 31 floats.
%%%
%%% Inputs (all normalized ~[-1, 1]):
%%%   1-2:   Relative food position (dx, dy) / grid_dim
%%%   3-4:   Relative opponent head (dx, dy) / grid_dim
%%%   5-8:   Danger in 4 directions (1.0 if wall/body/wall_tile adjacent, 0.0 otherwise)
%%%   9:     Own score / 20.0
%%%   10:    Opponent score / 20.0
%%%   11-14: Current direction one-hot [up, down, left, right]
%%%   15-16: Distance to nearest boundary wall (horizontal, vertical) normalized
%%%   17-18: Body length relative (own/20, opponent/20)
%%%   19-20: Nearest poison apple direction (dx, dy) / grid_dim (0,0 if none)
%%%   21-23: Look-ahead danger 2 cells (current dir, perpendicular right, perpendicular left)
%%%   24-25: Nearest wall tile direction (dx, dy) / grid_dim (0,0 if none)
%%%   26:    Own wall count on field / 5.0
%%%   27:    Can drop tail (1.0 if body >= 6, else 0.0)
%%%   28:    Own reachable space (flood fill cells / 50.0)
%%%   29:    Opponent reachable space (flood fill cells / 50.0)
%%%   30:    Space advantage (own - opp) / 50.0
%%%   31:    Trapped indicator (1.0 if own reachable < 8 cells, else 0.0)
%%% @end
-module(gladiator_sensor).
-behaviour(agent_sensor).

-include_lib("run_snake_duel/include/snake_duel.hrl").
-include("gladiator.hrl").

-export([name/0, input_count/0, read/2]).

-spec name() -> binary().
name() -> <<"gladiator_vision">>.

-spec input_count() -> pos_integer().
input_count() -> ?GLADIATOR_INPUTS.

-spec read(map(), map()) -> [float()].
read(_AgentState, #{game := Game}) ->
    #game_state{snake1 = S1, snake2 = S2, food = Food,
                poison_apples = PA, walls = Walls} = Game,
    #snake{body = [H1 | _] = Body1, direction = Dir1,
           score = Score1} = S1,
    #snake{body = [H2 | _] = Body2, score = Score2} = S2,

    %% 1-2: Relative food position
    {FoodDx, FoodDy} = relative_pos(H1, Food),

    %% 3-4: Relative opponent head
    {OppDx, OppDy} = relative_pos(H1, H2),

    %% 5-8: Danger in 4 directions (immediate adjacency, includes wall tiles)
    AllBodies = Body1 ++ Body2,
    PoisonPositions = [P#poison_apple.pos || P <- PA],
    WallPositions = [W#wall_tile.pos || W <- Walls],
    Obstacles = sets:from_list(AllBodies ++ PoisonPositions ++ WallPositions),
    DangerUp    = danger(H1, up, Obstacles),
    DangerDown  = danger(H1, down, Obstacles),
    DangerLeft  = danger(H1, left, Obstacles),
    DangerRight = danger(H1, right, Obstacles),

    %% 9-10: Normalized scores
    NormScore1 = Score1 / 20.0,
    NormScore2 = Score2 / 20.0,

    %% 11-14: Direction one-hot
    {DirUp, DirDown, DirLeft, DirRight} = direction_one_hot(Dir1),

    %% 15-16: Distance to nearest boundary wall (normalized 0..1)
    {WallH, WallV} = wall_distances(H1),

    %% 17-18: Body length relative (normalized by 20)
    BodyLen1 = length(Body1) / 20.0,
    BodyLen2 = length(Body2) / 20.0,

    %% 19-20: Nearest poison apple direction (0,0 if none)
    {PoisonDx, PoisonDy} = nearest_poison_dir(H1, PA),

    %% 21-23: Look-ahead danger 2 cells deep (forward, right, left)
    Danger2Forward = danger_at_distance(H1, Dir1, 2, Obstacles),
    PerpRightDir = perpendicular_right(Dir1),
    Danger2PerpRight = danger_at_distance(H1, PerpRightDir, 2, Obstacles),
    PerpLeftDir = perpendicular_left(Dir1),
    Danger2PerpLeft = danger_at_distance(H1, PerpLeftDir, 2, Obstacles),

    %% 24-25: Nearest wall tile direction (0,0 if none)
    {WallTileDx, WallTileDy} = nearest_wall_tile_dir(H1, Walls),

    %% 26: Own wall count on field / 5.0
    OwnWallCount = length([1 || #wall_tile{owner = player1} <- Walls]) / 5.0,

    %% 27: Can drop tail (1.0 if body >= 6, else 0.0)
    CanDrop = case length(Body1) >= 6 of true -> 1.0; false -> 0.0 end,

    %% 28-31: Reachable space sensors (BFS flood fill, max 50 cells)
    OwnReachable = flood_fill(H1, Obstacles, ?FLOOD_FILL_MAX),
    OppReachable = flood_fill(H2, Obstacles, ?FLOOD_FILL_MAX),
    NormOwn = OwnReachable / ?FLOOD_FILL_MAX,
    NormOpp = OppReachable / ?FLOOD_FILL_MAX,
    SpaceAdvantage = (OwnReachable - OppReachable) / ?FLOOD_FILL_MAX,
    Trapped = case OwnReachable < 8 of true -> 1.0; false -> 0.0 end,

    [FoodDx, FoodDy,
     OppDx, OppDy,
     DangerUp, DangerDown, DangerLeft, DangerRight,
     NormScore1, NormScore2,
     DirUp, DirDown, DirLeft, DirRight,
     WallH, WallV,
     BodyLen1, BodyLen2,
     PoisonDx, PoisonDy,
     Danger2Forward, Danger2PerpRight, Danger2PerpLeft,
     WallTileDx, WallTileDy,
     OwnWallCount, CanDrop,
     NormOwn, NormOpp, SpaceAdvantage, Trapped].

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

relative_pos({X1, Y1}, {X2, Y2}) ->
    {(X2 - X1) / ?GRID_WIDTH, (Y2 - Y1) / ?GRID_HEIGHT}.

danger({X, Y}, Dir, Obstacles) ->
    Next = step({X, Y}, Dir),
    case is_dangerous(Next, Obstacles) of
        true -> 1.0;
        false -> 0.0
    end.

step({X, Y}, up)    -> {X, Y - 1};
step({X, Y}, down)  -> {X, Y + 1};
step({X, Y}, left)  -> {X - 1, Y};
step({X, Y}, right) -> {X + 1, Y}.

is_dangerous({X, Y}, _Obstacles) when X < 0; X >= ?GRID_WIDTH;
                                       Y < 0; Y >= ?GRID_HEIGHT ->
    true;
is_dangerous(Pos, Obstacles) ->
    sets:is_element(Pos, Obstacles).

direction_one_hot(up)    -> {1.0, 0.0, 0.0, 0.0};
direction_one_hot(down)  -> {0.0, 1.0, 0.0, 0.0};
direction_one_hot(left)  -> {0.0, 0.0, 1.0, 0.0};
direction_one_hot(right) -> {0.0, 0.0, 0.0, 1.0}.

%% Distance to nearest wall in horizontal and vertical directions (normalized).
%% Returns {MinHorizontal, MinVertical} both in [0..1] range.
wall_distances({X, Y}) ->
    DistLeft = X / (?GRID_WIDTH - 1),
    DistRight = (?GRID_WIDTH - 1 - X) / (?GRID_WIDTH - 1),
    DistUp = Y / (?GRID_HEIGHT - 1),
    DistDown = (?GRID_HEIGHT - 1 - Y) / (?GRID_HEIGHT - 1),
    {min(DistLeft, DistRight), min(DistUp, DistDown)}.

%% Direction of nearest poison apple (0,0 if none).
nearest_poison_dir(_Head, []) ->
    {0.0, 0.0};
nearest_poison_dir({Hx, Hy} = _Head, PoisonApples) ->
    Distances = [{abs(Px - Hx) + abs(Py - Hy), P} ||
                 #poison_apple{pos = {Px, Py} = P} <- PoisonApples],
    {_MinDist, {Px, Py}} = lists:min(Distances),
    {(Px - Hx) / ?GRID_WIDTH, (Py - Hy) / ?GRID_HEIGHT}.

%% Direction of nearest wall tile (0,0 if none).
nearest_wall_tile_dir(_Head, []) ->
    {0.0, 0.0};
nearest_wall_tile_dir({Hx, Hy} = _Head, Walls) ->
    Distances = [{abs(Wx - Hx) + abs(Wy - Hy), W} ||
                 #wall_tile{pos = {Wx, Wy} = W} <- Walls],
    {_MinDist, {Wx, Wy}} = lists:min(Distances),
    {(Wx - Hx) / ?GRID_WIDTH, (Wy - Hy) / ?GRID_HEIGHT}.

%% Check if position N steps in direction Dir hits an obstacle.
danger_at_distance(Pos, Dir, N, Obstacles) ->
    FinalPos = step_n(Pos, Dir, N),
    case is_dangerous(FinalPos, Obstacles) of
        true -> 1.0;
        false -> 0.0
    end.

step_n(Pos, _Dir, 0) -> Pos;
step_n(Pos, Dir, N) when N > 0 -> step_n(step(Pos, Dir), Dir, N - 1).

%% Perpendicular direction (90 degrees clockwise).
perpendicular_right(up)    -> right;
perpendicular_right(right) -> down;
perpendicular_right(down)  -> left;
perpendicular_right(left)  -> up.

%% Perpendicular direction (90 degrees counter-clockwise).
perpendicular_left(up)    -> left;
perpendicular_left(left)  -> down;
perpendicular_left(down)  -> right;
perpendicular_left(right) -> up.

%% BFS flood fill from a position, avoiding obstacles and grid boundaries.
%% Returns number of reachable cells (capped at Max).
%% Uses queue module for proper BFS and maps for O(1) visited lookup.
flood_fill(Start, Obstacles, Max) ->
    case is_dangerous(Start, Obstacles) of
        true -> 0;
        false -> flood_fill_bfs(queue:in(Start, queue:new()), #{Start => true}, Obstacles, 0, Max)
    end.

flood_fill_bfs(_Queue, _Visited, _Obstacles, Count, Max) when Count >= Max ->
    Max;
flood_fill_bfs(Queue, Visited, Obstacles, Count, Max) ->
    case queue:out(Queue) of
        {empty, _} -> Count;
        {{value, Pos}, Queue1} ->
            Neighbors = [step(Pos, D) || D <- [up, down, left, right]],
            {Queue2, Visited2, Added} = lists:foldl(
                fun(N, {QAcc, VAcc, AAcc}) ->
                    case maps:is_key(N, VAcc) of
                        true -> {QAcc, VAcc, AAcc};
                        false ->
                            case is_dangerous(N, Obstacles) of
                                true -> {QAcc, VAcc#{N => true}, AAcc};
                                false -> {queue:in(N, QAcc), VAcc#{N => true}, AAcc + 1}
                            end
                    end
                end, {Queue1, Visited, 0}, Neighbors),
            NewCount = Count + Added,
            case NewCount >= Max of
                true -> Max;
                false -> flood_fill_bfs(Queue2, Visited2, Obstacles, NewCount, Max)
            end
    end.
