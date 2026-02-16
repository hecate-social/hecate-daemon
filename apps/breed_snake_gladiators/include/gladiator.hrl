%%% @doc Constants and topology for snake gladiator neuroevolution.
-ifndef(GLADIATOR_HRL).
-define(GLADIATOR_HRL, true).

%% Neural network topology: 22 inputs, [24, 12] hidden, 4 outputs
%% Inputs:
%%   1-2:   Relative food position (dx, dy) / grid_dim
%%   3-4:   Relative opponent head (dx, dy) / grid_dim
%%   5-8:   Danger in 4 directions (1.0 if wall/body adjacent, 0.0 otherwise)
%%   9:     Own score / 20.0
%%   10:    Opponent score / 20.0
%%   11-14: Current direction one-hot [up, down, left, right]
%%   15-16: Distance to nearest wall (horizontal, vertical) normalized
%%   17-18: Body length relative (own/20, opponent/20)
%%   19-20: Nearest poison apple direction (dx, dy) / grid_dim (0,0 if none)
%%   21-22: Look-ahead danger 2 cells (current dir, perpendicular right)
-define(GLADIATOR_INPUTS, 22).
-define(GLADIATOR_HIDDEN, [24, 12]).
-define(GLADIATOR_OUTPUTS, 4).
-define(GLADIATOR_TOPOLOGY, {?GLADIATOR_INPUTS, ?GLADIATOR_HIDDEN, ?GLADIATOR_OUTPUTS}).

%% Training defaults
-define(DEFAULT_POPULATION_SIZE, 50).
-define(DEFAULT_MAX_GENERATIONS, 100).
-define(DEFAULT_OPPONENT_AF, 50).
-define(DEFAULT_EPISODES_PER_EVAL, 3).
-define(DEFAULT_MAX_TICKS, 500).

%% Fitness weights
-define(FITNESS_SURVIVAL_WEIGHT, 0.1).
-define(FITNESS_FOOD_WEIGHT, 50.0).
-define(FITNESS_WIN_BONUS, 200.0).
-define(FITNESS_DRAW_BONUS, 50.0).
-define(FITNESS_KILL_BONUS, 100.0).        %% Win by opponent crash (not timeout)
-define(FITNESS_PROXIMITY_WEIGHT, 0.5).    %% Bonus for getting closer to food
-define(FITNESS_CIRCLE_PENALTY, -0.2).     %% Penalty per revisited position

%% Direction output indices (0-based)
-define(DIR_UP, 0).
-define(DIR_DOWN, 1).
-define(DIR_LEFT, 2).
-define(DIR_RIGHT, 3).

-endif.
