%%% @doc Sale status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(SALE_INITIATED, 1).   %% 2^0
-define(SALE_ARCHIVED,  32).  %% 2^5

-define(SALE_FLAG_MAP, #{
    1  => <<"Initiated">>,
    32 => <<"Archived">>
}).
