%%% @doc Launcher status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(LNCH_INITIALIZED, 1).  %% Launcher has been initialized
-define(LNCH_CONFIGURED,  2).  %% At least one configuration change applied

-define(LNCH_FLAG_MAP, #{
    1 => <<"Initialized">>,
    2 => <<"Configured">>
}).
