-module(query_venture_lifecycle_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/venture", get_active_venture_api, []},
        {"/api/ventures", get_ventures_page_api, []},
        {"/api/ventures/:venture_id", get_venture_by_id_api, []},
        {"/api/ventures/:venture_id/status", get_venture_status_api, []},
        {"/api/ventures/:venture_id/tasks", get_venture_tasks_api, []},
        {"/api/ventures/:venture_id/divisions", get_discovered_divisions_page_api, []}
    ].
