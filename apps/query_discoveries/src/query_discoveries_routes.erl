-module(query_discoveries_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/discovery", get_discovery_by_venture_id_api, []},
        {"/api/ventures/:venture_id/divisions", get_discovered_divisions_page_api, []}
    ].
