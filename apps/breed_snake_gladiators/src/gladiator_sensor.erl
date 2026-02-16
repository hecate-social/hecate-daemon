%%% @doc Sensor for snake gladiator — reads game state into 22 floats.
%%%
%%% Inputs (all normalized ~[-1, 1]):
%%%   1-2:   Relative food position (dx, dy) / grid_dim
%%%   3-4:   Relative opponent head (dx, dy) / grid_dim
%%%   5-8:   Danger in 4 directions (1.0 if wall/body adjacent, 0.0 otherwise)
%%%   9:     Own score / 20.0
%%%   10:    Opponent score / 20.0
%%%   11-14: Current direction one-hot [up, down, left, right]
%%%   15-16: Distance to nearest wall (horizontal, vertical) normalized
%%%   17-18: Body length relative (own/20, opponent/20)
%%%   19-20: Nearest poison apple direction (dx, dy) / grid_dim (0,0 if none)
%%%   21-22: Look-ahead danger 2 cells (current dir, perpendicular right)
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
                poison_apples = PA} = Game,
    #snake{body = [H1 | _] = Body1, direction = Dir1,
           score = Score1} = S1,
    #snake{body = [H2 | _] = Body2, score = Score2} = S2,

    %% 1-2: Relative food position
    {FoodDx, FoodDy} = relative_pos(H1, Food),

    %% 3-4: Relative opponent head
    {OppDx, OppDy} = relative_pos(H1, H2),

    %% 5-8: Danger in 4 directions (immediate adjacency)
    AllBodies = Body1 ++ Body2,
    PoisonPositions = [P#poison_apple.pos || P <- PA],
    Obstacles = sets:from_list(AllBodies ++ PoisonPositions),
    DangerUp    = danger(H1, up, Obstacles),
    DangerDown  = danger(H1, down, Obstacles),
    DangerLeft  = danger(H1, left, Obstacles),
    DangerRight = danger(H1, right, Obstacles),

    %% 9-10: Normalized scores
    NormScore1 = Score1 / 20.0,
    NormScore2 = Score2 / 20.0,

    %% 11-14: Direction one-hot
    {DirUp, DirDown, DirLeft, DirRight} = direction_one_hot(Dir1),

    %% 15-16: Distance to nearest wall (normalized 0..1)
    {WallH, WallV} = wall_distances(H1),

    %% 17-18: Body length relative (normalized by 20)
    BodyLen1 = length(Body1) / 20.0,
    BodyLen2 = length(Body2) / 20.0,

    %% 19-20: Nearest poison apple direction (0,0 if none)
    {PoisonDx, PoisonDy} = nearest_poison_dir(H1, PA),

    %% 21-22: Look-ahead danger 2 cells deep
    Danger2Forward = danger_at_distance(H1, Dir1, 2, Obstacles),
    PerpDir = perpendicular_right(Dir1),
    Danger2Perp = danger_at_distance(H1, PerpDir, 2, Obstacles),

    [FoodDx, FoodDy,
     OppDx, OppDy,
     DangerUp, DangerDown, DangerLeft, DangerRight,
     NormScore1, NormScore2,
     DirUp, DirDown, DirLeft, DirRight,
     WallH, WallV,
     BodyLen1, BodyLen2,
     PoisonDx, PoisonDy,
     Danger2Forward, Danger2Perp].

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
