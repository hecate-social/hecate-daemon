-module(manage_capabilities_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/capabilities/announce", announce_capability_api, []},
        {"/api/capabilities/:mri/update", update_capability_api, []},
        {"/api/capabilities/:mri/retract", retract_capability_api, []}
    ].
