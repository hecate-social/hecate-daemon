%%% @doc Status bit flags for the plan aggregate.
%%%
%%% Plan lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(PLAN_INITIATED,  1).   %% 2^0 — plan process created
-define(PLAN_ACTIVE,     2).   %% 2^1 — actively planning
-define(PLAN_PAUSED,     4).   %% 2^2 — temporarily paused
-define(PLAN_COMPLETED,  8).   %% 2^3 — plan complete
-define(PLAN_ARCHIVED,  16).   %% 2^4 — soft-deleted

-define(PLAN_FLAG_MAP, #{
    ?PLAN_INITIATED  => <<"Initiated"/utf8>>,
    ?PLAN_ACTIVE     => <<"Active"/utf8>>,
    ?PLAN_PAUSED     => <<"Paused"/utf8>>,
    ?PLAN_COMPLETED  => <<"Completed"/utf8>>,
    ?PLAN_ARCHIVED   => <<"Archived"/utf8>>
}).
