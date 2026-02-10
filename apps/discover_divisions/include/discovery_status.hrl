%%% @doc Status bit flags for the discovery aggregate.
%%%
%%% Discovery lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(DISCOVERY_INITIATED,  1).   %% 2^0 — discovery process created
-define(DISCOVERY_ACTIVE,     2).   %% 2^1 — actively discovering
-define(DISCOVERY_PAUSED,     4).   %% 2^2 — temporarily paused
-define(DISCOVERY_COMPLETED,  8).   %% 2^3 — discovery complete
-define(DISCOVERY_ARCHIVED,  16).   %% 2^4 — soft-deleted

-define(DISCOVERY_FLAG_MAP, #{
    ?DISCOVERY_INITIATED  => <<"Initiated"/utf8>>,
    ?DISCOVERY_ACTIVE     => <<"Active"/utf8>>,
    ?DISCOVERY_PAUSED     => <<"Paused"/utf8>>,
    ?DISCOVERY_COMPLETED  => <<"Completed"/utf8>>,
    ?DISCOVERY_ARCHIVED   => <<"Archived"/utf8>>
}).
