%%% @doc Venture status bit flags and flag map.
%%% Include via: -include_lib("setup_venture/include/venture_status.hrl").

-ifndef(VENTURE_STATUS_HRL).
-define(VENTURE_STATUS_HRL, true).

-define(VENTURE_SETUP,          1).   %% 2^0 (venture is set up)
-define(VENTURE_VISION_REFINED, 2).   %% 2^1 (vision has been refined)
-define(VENTURE_SUBMITTED,      4).   %% 2^2 (vision submitted, setup complete)
-define(VENTURE_ARCHIVED,       8).   %% 2^3 (soft deleted)

-define(VENTURE_FLAG_MAP, #{
    0                       => <<"New">>,
    ?VENTURE_SETUP          => <<"Setup">>,
    ?VENTURE_VISION_REFINED => <<"Vision Refined">>,
    ?VENTURE_SUBMITTED      => <<"Submitted">>,
    ?VENTURE_ARCHIVED       => <<"Archived">>
}).

-endif.
