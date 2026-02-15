%%% IRC channel status bit flags
-ifndef(IRC_CHANNEL_STATUS_HRL).
-define(IRC_CHANNEL_STATUS_HRL, true).

-define(IRC_INITIATED, 1).
-define(IRC_ARCHIVED,  2).

-define(IRC_FLAG_MAP, #{
    ?IRC_INITIATED => <<"Opened">>,
    ?IRC_ARCHIVED  => <<"Closed">>
}).

-endif.
