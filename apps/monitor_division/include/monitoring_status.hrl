%%% @doc Status bit flags for the monitoring aggregate.
%%%
%%% Monitoring lifecycle: pending -> active -> paused -> completed
%%% Archive is orthogonal (walking skeleton).
%%% @end

-define(MONITORING_INITIATED,  1).
-define(MONITORING_ACTIVE,     2).
-define(MONITORING_PAUSED,     4).
-define(MONITORING_COMPLETED,  8).
-define(MONITORING_ARCHIVED,  16).

-define(MONITORING_FLAG_MAP, #{
    ?MONITORING_INITIATED  => <<"Initiated"/utf8>>,
    ?MONITORING_ACTIVE     => <<"Active"/utf8>>,
    ?MONITORING_PAUSED     => <<"Paused"/utf8>>,
    ?MONITORING_COMPLETED  => <<"Completed"/utf8>>,
    ?MONITORING_ARCHIVED   => <<"Archived"/utf8>>
}).
