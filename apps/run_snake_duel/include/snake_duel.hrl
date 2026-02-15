%%% @doc Snake Duel types and constants.
-ifndef(SNAKE_DUEL_HRL).
-define(SNAKE_DUEL_HRL, true).

%% Grid dimensions
-define(GRID_WIDTH, 30).
-define(GRID_HEIGHT, 24).
-define(DEFAULT_TICK_MS, 100).

%% Types
-type direction() :: up | down | left | right.
-type game_status() :: idle | countdown | running | finished.
-type player_tag() :: player1 | player2.
-type point() :: {integer(), integer()}.

-record(game_event, {
    type  :: food | turn | collision | win | poison_drop | poison_eat,
    value :: binary(),
    tick  :: non_neg_integer()
}).
-type game_event() :: #game_event{}.

-record(snake, {
    body           :: [point()],
    direction      :: direction(),
    score = 0      :: integer(),
    asshole_factor :: non_neg_integer(),
    events = []    :: [game_event()]
}).
-type snake() :: #snake{}.

-record(poison_apple, {
    pos   :: point(),
    owner :: player_tag()
}).
-type poison_apple() :: #poison_apple{}.

-record(game_state, {
    snake1        :: snake(),
    snake2        :: snake(),
    food          :: point(),
    poison_apples :: [poison_apple()],
    status        :: game_status(),
    winner = none :: player_tag() | draw | none,
    tick = 0      :: non_neg_integer(),
    countdown = 3 :: non_neg_integer()
}).
-type game_state() :: #game_state{}.

%% Duel aggregate status flags (bit flags)
-define(DUEL_INITIATED, 1).    %% 2^0
-define(DUEL_RUNNING,   2).    %% 2^1
-define(DUEL_FINISHED,  4).    %% 2^2
-define(DUEL_ARCHIVED,  8).    %% 2^3

-define(DUEL_FLAG_MAP, #{
    1 => <<"initiated">>,
    2 => <<"running">>,
    4 => <<"finished">>,
    8 => <<"archived">>
}).

-endif.
