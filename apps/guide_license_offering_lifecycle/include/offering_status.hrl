%%% @doc Offering status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(OFF_INITIATED,   1).   %% 2^0 Author created the offering
-define(OFF_ANNOUNCED,   2).   %% 2^1 Pre-publish marketing
-define(OFF_PUBLISHED,   4).   %% 2^2 Available for purchase on mesh
-define(OFF_ARCHIVED,   32).   %% 2^5 Walking skeleton

-define(OFF_FLAG_MAP, #{
    1  => <<"Initiated">>,
    2  => <<"Announced">>,
    4  => <<"Published">>,
    32 => <<"Archived">>
}).
