%%% @doc Bit flags for LAN machine aggregate status.
-ifndef(LAN_MACHINE_STATUS_HRL).
-define(LAN_MACHINE_STATUS_HRL, true).

-define(LAN_MACHINE_SPOTTED,   1).  %% 2^0 — seen on network
-define(LAN_MACHINE_DISMISSED,  2).  %% 2^1 — user hid from list

-endif.
