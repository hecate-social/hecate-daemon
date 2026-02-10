%%% @doc Status bit flags for the testing aggregate.
%%%
%%% Testing lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(TESTING_INITIATED,  1).
-define(TESTING_ACTIVE,     2).
-define(TESTING_PAUSED,     4).
-define(TESTING_COMPLETED,  8).
-define(TESTING_ARCHIVED,  16).

-define(TESTING_FLAG_MAP, #{
    ?TESTING_INITIATED  => <<"Initiated"/utf8>>,
    ?TESTING_ACTIVE     => <<"Active"/utf8>>,
    ?TESTING_PAUSED     => <<"Paused"/utf8>>,
    ?TESTING_COMPLETED  => <<"Completed"/utf8>>,
    ?TESTING_ARCHIVED   => <<"Archived"/utf8>>
}).
