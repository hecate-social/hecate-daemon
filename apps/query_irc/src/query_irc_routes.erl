-module(query_irc_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/irc/channels", get_channels_page_api, []}
    ].
