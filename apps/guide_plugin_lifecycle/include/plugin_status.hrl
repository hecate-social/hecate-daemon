%%% @doc Plugin status bit flags (node context).
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

%% Common flags
-define(PLG_INSTALLED,       1).   %% Plugin is installed
-define(PLG_REMOVED,         2).   %% Plugin has been removed

%% Container-model flags
-define(PLG_RUNNING,         4).   %% Container execution requested
-define(PLG_STOPPED,         8).   %% Container execution stop requested
-define(PLG_CONFIRMED_UP,   16).   %% Container confirmed running (socket alive)
-define(PLG_CONFIRMED_DOWN, 32).   %% Container confirmed down (socket gone)
-define(PLG_PULLING,        64).   %% OCI image pull in progress

%% In-VM model flags
-define(PLG_EXTRACTING,    128).   %% Package extraction in progress
-define(PLG_ACTIVATED,     256).   %% Plugin activated (code loaded, routes mounted)
-define(PLG_DEACTIVATED,   512).   %% Plugin deactivated (code unloaded)

-define(PLG_FLAG_MAP, #{
    1   => <<"Installed">>,
    2   => <<"Removed">>,
    4   => <<"Running">>,
    8   => <<"Stopped">>,
    16  => <<"ConfirmedUp">>,
    32  => <<"ConfirmedDown">>,
    64  => <<"Pulling">>,
    128 => <<"Extracting">>,
    256 => <<"Activated">>,
    512 => <<"Deactivated">>
}).
