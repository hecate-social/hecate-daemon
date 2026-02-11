-module(manage_identities_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/identities/register", register_identity_api, []},
        {"/api/identities/:agent_identity/update", update_identity_api, []}
    ].
