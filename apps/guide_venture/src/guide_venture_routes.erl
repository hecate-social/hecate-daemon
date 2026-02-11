-module(guide_venture_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/status", get_venture_status_api, []},
        {"/api/ventures/:venture_id/tasks", get_venture_tasks_api, []}
    ].
