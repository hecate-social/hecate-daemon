%%% @doc Bit flags for realm membership aggregate status.
-ifndef(MEMBERSHIP_STATUS_HRL).
-define(MEMBERSHIP_STATUS_HRL, true).

-define(MEMBERSHIP_INITIATED, 1).  %% 2^0
-define(MEMBERSHIP_CONFIRMED, 2).  %% 2^1
-define(MEMBERSHIP_REVOKED,   4).  %% 2^2

-endif.
