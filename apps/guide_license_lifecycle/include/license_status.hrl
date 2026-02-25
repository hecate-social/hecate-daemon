%%% @doc License status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

%% Seller-side flags
-define(LIC_INITIATED,   1).   %% 2^0 Seller created the offering
-define(LIC_ANNOUNCED,   2).   %% 2^1 Pre-publish marketing
-define(LIC_PUBLISHED,   4).   %% 2^2 Available for purchase on mesh

%% Buyer-side flags
-define(LIC_LICENSED,    8).   %% 2^3 User has acquired license (free or paid)
-define(LIC_REVOKED,    16).   %% 2^4 License has been revoked
-define(LIC_ARCHIVED,   32).   %% 2^5 Walking skeleton

-define(LIC_FLAG_MAP, #{
    1  => <<"Initiated">>,
    2  => <<"Announced">>,
    4  => <<"Published">>,
    8  => <<"Licensed">>,
    16 => <<"Revoked">>,
    32 => <<"Archived">>
}).
