-module(query_ventures_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/venture", get_active_venture_api, []},
        {"/api/ventures", get_ventures_page_api, []},
        {"/api/ventures/:venture_id", get_venture_by_id_api, []}
    ].
