%%% @doc Bit flags for MPong game aggregate status.
-ifndef(MPONG_GAME_STATUS_HRL).
-define(MPONG_GAME_STATUS_HRL, true).

-define(MPONG_HOSTED,    1).   %% 2^0 — game has been hosted, waiting for players
-define(MPONG_STARTED,   2).   %% 2^1 — game is in progress
-define(MPONG_ENDED,     4).   %% 2^2 — game has ended (winner or forced)
-define(MPONG_CANCELLED, 8).   %% 2^3 — game was cancelled before starting

-endif.
