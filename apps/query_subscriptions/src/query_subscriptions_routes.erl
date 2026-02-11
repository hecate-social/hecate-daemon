-module(query_subscriptions_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/subscriptions", get_subscriptions_by_agent_api, []},
        {"/api/subscriptions/stats", get_subscription_stats_api, []}
    ].
