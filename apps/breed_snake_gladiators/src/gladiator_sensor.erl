%%% @doc Sensor for snake gladiator — reads game state into 14 floats.
%%%
%%% Inputs (all normalized ~[-1, 1]):
%%%   1-2:   Relative food position (dx, dy) / grid_dim
%%%   3-4:   Relative opponent head (dx, dy) / grid_dim
%%%   5-8:   Danger in 4 directions (1.0 if wall/body adjacent, 0.0 otherwise)
%%%   9:     Own score / 20.0
%%%   10:    Opponent score / 20.0
%%%   11-14: Current direction one-hot [up, down, left, right]
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

    %% 5-8: Danger in 4 directions
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

    [FoodDx, FoodDy,
     OppDx, OppDy,
     DangerUp, DangerDown, DangerLeft, DangerRight,
     NormScore1, NormScore2,
     DirUp, DirDown, DirLeft, DirRight].

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

relative_pos({X1, Y1}, {X2, Y2}) ->
    {(X2 - X1) / ?GRID_WIDTH, (Y2 - Y1) / ?GRID_HEIGHT}.

danger({X, Y}, Dir, Obstacles) ->
    Next = case Dir of
        up    -> {X, Y - 1};
        down  -> {X, Y + 1};
        left  -> {X - 1, Y};
        right -> {X + 1, Y}
    end,
    case is_dangerous(Next, Obstacles) of
        true -> 1.0;
        false -> 0.0
    end.

is_dangerous({X, Y}, _Obstacles) when X < 0; X >= ?GRID_WIDTH;
                                       Y < 0; Y >= ?GRID_HEIGHT ->
    true;
is_dangerous(Pos, Obstacles) ->
    sets:is_element(Pos, Obstacles).

direction_one_hot(up)    -> {1.0, 0.0, 0.0, 0.0};
direction_one_hot(down)  -> {0.0, 1.0, 0.0, 0.0};
direction_one_hot(left)  -> {0.0, 0.0, 1.0, 0.0};
direction_one_hot(right) -> {0.0, 0.0, 0.0, 1.0}.
