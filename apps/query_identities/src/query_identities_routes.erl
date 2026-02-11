-module(query_identities_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/identities", get_identities_page_api, []},
        {"/api/identities/:agent_identity", find_identity_api, []}
    ].
