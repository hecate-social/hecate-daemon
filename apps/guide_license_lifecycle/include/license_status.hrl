%%% @doc Consumer license status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(LIC_INITIATED,  1).   %% 2^0 Consumer started license process
-define(LIC_ACCEPTED,   2).   %% 2^1 Consumer accepted offering terms
-define(LIC_BOUGHT,     4).   %% 2^2 Payment completed
-define(LIC_GRANTED,    8).   %% 2^3 License active (free or paid)
-define(LIC_EXPIRED,   16).   %% 2^4 License expired
-define(LIC_REVOKED,   32).   %% 2^5 License revoked (enforcement)
-define(LIC_ARCHIVED,  64).   %% 2^6 Walking skeleton

-define(LIC_FLAG_MAP, #{
    1  => <<"Initiated">>,
    2  => <<"Accepted">>,
    4  => <<"Bought">>,
    8  => <<"Granted">>,
    16 => <<"Expired">>,
    32 => <<"Revoked">>,
    64 => <<"Archived">>
}).
