-module(query_plans_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/plan", get_plan_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/desks", get_planned_desks_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/dependencies", get_planned_dependencies_page_api, []}
    ].
