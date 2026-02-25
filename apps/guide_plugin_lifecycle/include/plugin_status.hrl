%%% @doc Plugin status bit flags (node context).
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(PLG_INSTALLED, 1).   %% Plugin is installed, .container exists
-define(PLG_REMOVED,   2).   %% Plugin has been removed

-define(PLG_FLAG_MAP, #{
    1 => <<"Installed">>,
    2 => <<"Removed">>
}).
