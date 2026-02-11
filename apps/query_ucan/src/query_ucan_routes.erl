-module(query_ucan_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ucan/capabilities", find_ucan_capabilities_api, []},
        {"/api/ucan/verify/:capability_id", verify_ucan_api, []},
        {"/api/ucan/verify", verify_ucan_api, []}
    ].
