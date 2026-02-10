%%% @doc Status bit flags for the rescue aggregate.
%%%
%%% Rescue lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(RESCUE_INITIATED,  1).
-define(RESCUE_ACTIVE,     2).
-define(RESCUE_PAUSED,     4).
-define(RESCUE_COMPLETED,  8).
-define(RESCUE_ARCHIVED,  16).

-define(RESCUE_FLAG_MAP, #{
    ?RESCUE_INITIATED  => <<"Initiated"/utf8>>,
    ?RESCUE_ACTIVE     => <<"Active"/utf8>>,
    ?RESCUE_PAUSED     => <<"Paused"/utf8>>,
    ?RESCUE_COMPLETED  => <<"Completed"/utf8>>,
    ?RESCUE_ARCHIVED   => <<"Archived"/utf8>>
}).
