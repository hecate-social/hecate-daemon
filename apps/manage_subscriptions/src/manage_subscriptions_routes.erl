-module(manage_subscriptions_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/subscriptions/subscribe", subscribe_api, []},
        {"/api/subscriptions/unsubscribe", unsubscribe_api, []}
    ].
