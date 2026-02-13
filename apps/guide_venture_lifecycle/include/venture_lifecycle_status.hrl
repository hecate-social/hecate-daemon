%%% @doc Status bit flags for the venture lifecycle aggregate.
%%%
%%% Venture lifecycle: initiated -> discovering -> discovery_completed
%%% Vision refinement and submission happen between initiation and discovery.
%%% Archive is orthogonal (walking skeleton).
%%% @end

-ifndef(VENTURE_LIFECYCLE_STATUS_HRL).
-define(VENTURE_LIFECYCLE_STATUS_HRL, true).

-define(VL_INITIATED,           1).   %% 2^0
-define(VL_VISION_REFINED,      2).   %% 2^1
-define(VL_SUBMITTED,           4).   %% 2^2
-define(VL_DISCOVERING,         8).   %% 2^3
-define(VL_DISCOVERY_PAUSED,   16).   %% 2^4
-define(VL_DISCOVERY_COMPLETED, 32).  %% 2^5
-define(VL_ARCHIVED,           64).   %% 2^6
-define(VL_STORMING,          128).   %% 2^7
-define(VL_STORM_SHELVED,     256).   %% 2^8

-define(VL_FLAG_MAP, #{
    ?VL_INITIATED           => <<"Initiated">>,
    ?VL_VISION_REFINED      => <<"Vision Refined">>,
    ?VL_SUBMITTED           => <<"Submitted">>,
    ?VL_DISCOVERING         => <<"Discovering">>,
    ?VL_DISCOVERY_PAUSED    => <<"Discovery Paused">>,
    ?VL_DISCOVERY_COMPLETED => <<"Discovery Completed">>,
    ?VL_ARCHIVED            => <<"Archived">>,
    ?VL_STORMING            => <<"Storming">>,
    ?VL_STORM_SHELVED       => <<"Storm Shelved">>
}).

-endif.
