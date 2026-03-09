%%% @doc Payment status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(PAY_INITIATED,  1).   %% 2^0
-define(PAY_ARCHIVED,  32).   %% 2^5

-define(PAY_FLAG_MAP, #{
    1  => <<"Initiated">>,
    32 => <<"Archived">>
}).
