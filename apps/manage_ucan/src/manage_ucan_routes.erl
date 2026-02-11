-module(manage_ucan_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ucan/grant", grant_ucan_api, []},
        {"/api/ucan/revoke/:capability_id", revoke_ucan_api, []}
    ].
