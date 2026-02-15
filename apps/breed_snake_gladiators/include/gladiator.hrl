%%% @doc Constants and topology for snake gladiator neuroevolution.
-ifndef(GLADIATOR_HRL).
-define(GLADIATOR_HRL, true).

%% Neural network topology: 14 inputs, [16, 8] hidden, 4 outputs
-define(GLADIATOR_INPUTS, 14).
-define(GLADIATOR_HIDDEN, [16, 8]).
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

%% Direction output indices (0-based)
-define(DIR_UP, 0).
-define(DIR_DOWN, 1).
-define(DIR_LEFT, 2).
-define(DIR_RIGHT, 3).

-endif.
