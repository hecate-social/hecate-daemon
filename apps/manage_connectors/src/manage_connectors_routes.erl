-module(manage_connectors_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/connectors", list_connectors_api, []},
        {"/api/connectors/register", register_connector_api, []},
        {"/api/connectors/:connector_id", get_connector_api, []},
        {"/api/connectors/:connector_id/revoke", revoke_connector_api, []}
    ].
