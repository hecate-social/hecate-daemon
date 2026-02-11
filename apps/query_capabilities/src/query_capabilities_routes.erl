-module(query_capabilities_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/capabilities", get_capabilities_page_api, []},
        {"/api/capabilities/:mri", get_capability_by_mri_api, []}
    ].
