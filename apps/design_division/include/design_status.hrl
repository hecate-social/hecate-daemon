%%% @doc Status bit flags for the design aggregate.
%%%
%%% Design lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(DESIGN_INITIATED,  1).   %% 2^0 — design process created
-define(DESIGN_ACTIVE,     2).   %% 2^1 — actively designing
-define(DESIGN_PAUSED,     4).   %% 2^2 — temporarily paused
-define(DESIGN_COMPLETED,  8).   %% 2^3 — design complete
-define(DESIGN_ARCHIVED,  16).   %% 2^4 — soft-deleted

-define(DESIGN_FLAG_MAP, #{
    ?DESIGN_INITIATED  => <<"Initiated"/utf8>>,
    ?DESIGN_ACTIVE     => <<"Active"/utf8>>,
    ?DESIGN_PAUSED     => <<"Paused"/utf8>>,
    ?DESIGN_COMPLETED  => <<"Completed"/utf8>>,
    ?DESIGN_ARCHIVED   => <<"Archived"/utf8>>
}).
