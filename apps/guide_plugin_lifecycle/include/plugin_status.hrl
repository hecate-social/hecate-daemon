%%% @doc Plugin status bit flags (node context).
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(PLG_INSTALLED,     1).   %% Plugin is installed, .container exists
-define(PLG_REMOVED,       2).   %% Plugin has been removed
-define(PLG_RUNNING,       4).   %% Plugin execution requested (starting)
-define(PLG_STOPPED,       8).   %% Plugin execution stop requested (stopping)
-define(PLG_CONFIRMED_UP,  16).  %% Container confirmed running (socket alive)
-define(PLG_CONFIRMED_DOWN,32).  %% Container confirmed down (socket gone)
-define(PLG_PULLING,      64).  %% Container starting / pulling image

-define(PLG_FLAG_MAP, #{
    1  => <<"Installed">>,
    2  => <<"Removed">>,
    4  => <<"Running">>,
    8  => <<"Stopped">>,
    16 => <<"ConfirmedUp">>,
    32 => <<"ConfirmedDown">>,
    64 => <<"Pulling">>
}).
