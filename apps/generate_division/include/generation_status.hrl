%%% @doc Status bit flags for the generation aggregate.
%%%
%%% Generation lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(GENERATION_INITIATED,  1).
-define(GENERATION_ACTIVE,     2).
-define(GENERATION_PAUSED,     4).
-define(GENERATION_COMPLETED,  8).
-define(GENERATION_ARCHIVED,  16).

-define(GENERATION_FLAG_MAP, #{
    ?GENERATION_INITIATED  => <<"Initiated"/utf8>>,
    ?GENERATION_ACTIVE     => <<"Active"/utf8>>,
    ?GENERATION_PAUSED     => <<"Paused"/utf8>>,
    ?GENERATION_COMPLETED  => <<"Completed"/utf8>>,
    ?GENERATION_ARCHIVED   => <<"Archived"/utf8>>
}).
