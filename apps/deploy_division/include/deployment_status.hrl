%%% @doc Status bit flags for the deployment aggregate.
%%%
%%% Deployment lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(DEPLOYMENT_INITIATED,  1).
-define(DEPLOYMENT_ACTIVE,     2).
-define(DEPLOYMENT_PAUSED,     4).
-define(DEPLOYMENT_COMPLETED,  8).
-define(DEPLOYMENT_ARCHIVED,  16).

-define(DEPLOYMENT_FLAG_MAP, #{
    ?DEPLOYMENT_INITIATED  => <<"Initiated"/utf8>>,
    ?DEPLOYMENT_ACTIVE     => <<"Active"/utf8>>,
    ?DEPLOYMENT_PAUSED     => <<"Paused"/utf8>>,
    ?DEPLOYMENT_COMPLETED  => <<"Completed"/utf8>>,
    ?DEPLOYMENT_ARCHIVED   => <<"Archived"/utf8>>
}).
