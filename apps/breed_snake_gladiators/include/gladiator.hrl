%%% @doc Constants and topology for snake gladiator neuroevolution.
-ifndef(GLADIATOR_HRL).
-define(GLADIATOR_HRL, true).

%% Neural network topology: 31 inputs, [34, 16] hidden, 5 outputs
%% Inputs:
%%   1-2:   Relative food position (dx, dy) / grid_dim
%%   3-4:   Relative opponent head (dx, dy) / grid_dim
%%   5-8:   Danger in 4 directions (1.0 if wall/body/wall_tile adjacent, 0.0 otherwise)
%%   9:     Own score / 20.0
%%   10:    Opponent score / 20.0
%%   11-14: Current direction one-hot [up, down, left, right]
%%   15-16: Distance to nearest boundary wall (horizontal, vertical) normalized
%%   17-18: Body length relative (own/20, opponent/20)
%%   19-20: Nearest poison apple direction (dx, dy) / grid_dim (0,0 if none)
%%   21-23: Look-ahead danger 2 cells (current dir, perpendicular right, perpendicular left)
%%   24-25: Nearest wall tile direction (dx, dy) / grid_dim (0,0 if none)
%%   26:    Own wall count on field / 5.0
%%   27:    Can drop tail (1.0 if body >= 6, else 0.0)
%%   28:    Own reachable space (flood fill cells / 50.0)
%%   29:    Opponent reachable space (flood fill cells / 50.0)
%%   30:    Space advantage (own - opp) / 50.0
%%   31:    Trapped indicator (1.0 if own reachable < 8 cells, else 0.0)
%% Outputs:
%%   1-4:   Direction [up, down, left, right]
%%   5:     Drop tail signal (> 0.5 = drop)
-define(GLADIATOR_INPUTS, 31).
-define(GLADIATOR_HIDDEN, [34, 16]).
-define(GLADIATOR_OUTPUTS, 5).
-define(GLADIATOR_TOPOLOGY, {?GLADIATOR_INPUTS, ?GLADIATOR_HIDDEN, ?GLADIATOR_OUTPUTS}).

%% Old topology (for backward compatibility detection)
-define(GLADIATOR_INPUTS_V2, 27).
-define(GLADIATOR_INPUTS_V1, 22).
-define(GLADIATOR_OUTPUTS_V1, 4).

%% Training defaults
-define(DEFAULT_POPULATION_SIZE, 50).
-define(DEFAULT_MAX_GENERATIONS, 100).
-define(DEFAULT_OPPONENT_AF, 50).
-define(DEFAULT_EPISODES_PER_EVAL, 5).
-define(DEFAULT_MAX_TICKS, 500).

%% Champion selection
-define(DEFAULT_CHAMPION_COUNT, 3).
-define(MAX_CHAMPION_COUNT, 10).

%% LTC neurons
-define(DEFAULT_ENABLE_LTC, false).

%% LC chain (adaptive hyperparameter control)
-define(DEFAULT_ENABLE_LC_CHAIN, false).

%% Flood fill for reachable-space sensors
-define(FLOOD_FILL_MAX, 50).

%% Fitness weights
-define(FITNESS_SURVIVAL_WEIGHT, 0.1).
-define(FITNESS_FOOD_WEIGHT, 50.0).
-define(FITNESS_WIN_BONUS, 200.0).
-define(FITNESS_DRAW_BONUS, 50.0).
-define(FITNESS_KILL_BONUS, 100.0).        %% Win by opponent crash (not timeout)
-define(FITNESS_PROXIMITY_WEIGHT, 0.5).    %% Bonus for getting closer to food
-define(FITNESS_CIRCLE_PENALTY, -1.0).     %% Penalty per revisited position

%% Default fitness weights (map form for configurable weights)
-define(DEFAULT_FITNESS_WEIGHTS, #{
    survival_weight   => 0.1,
    food_weight       => 50.0,
    win_bonus         => 200.0,
    draw_bonus        => 50.0,
    kill_bonus        => 100.0,
    proximity_weight  => 0.5,
    circle_penalty    => -1.0,
    wall_kill_bonus   => 75.0
}).

%% Bounds: {Min, Max} per weight
-define(FITNESS_WEIGHT_BOUNDS, #{
    survival_weight   => {0.0, 1.0},
    food_weight       => {0.0, 200.0},
    win_bonus         => {0.0, 500.0},
    draw_bonus        => {0.0, 200.0},
    kill_bonus        => {0.0, 300.0},
    proximity_weight  => {0.0, 5.0},
    circle_penalty    => {-2.0, 0.0},
    wall_kill_bonus   => {0.0, 200.0}
}).

%% Impact factors for tuning cost calculation
-define(FITNESS_WEIGHT_IMPACTS, #{
    win_bonus         => 3.0,
    kill_bonus        => 2.5,
    food_weight       => 2.0,
    wall_kill_bonus   => 2.0,
    draw_bonus        => 1.5,
    proximity_weight  => 1.0,
    survival_weight   => 1.0,
    circle_penalty    => 0.5
}).

%% Tuning budget: max total deviation cost
-define(DEFAULT_TUNING_BUDGET, 100.0).

%% Direction output indices (0-based)
-define(DIR_UP, 0).
-define(DIR_DOWN, 1).
-define(DIR_LEFT, 2).
-define(DIR_RIGHT, 3).

-endif.
