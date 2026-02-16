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
    type  :: food | turn | collision | win | poison_drop | poison_eat | wall_drop | wall_hit,
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

%% Wall tile — decaying fortification dropped from tail
-define(WALL_TTL, 25).

-record(wall_tile, {
    pos   :: point(),
    owner :: player_tag(),
    ttl   :: non_neg_integer()
}).
-type wall_tile() :: #wall_tile{}.

-record(game_state, {
    snake1        :: snake(),
    snake2        :: snake(),
    food          :: point(),
    poison_apples :: [poison_apple()],
    walls = []    :: [wall_tile()],
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
