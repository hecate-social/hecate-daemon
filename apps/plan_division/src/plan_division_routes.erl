-module(plan_division_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/plan/start", start_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/pause", pause_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/resume", resume_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/complete", complete_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/archive", archive_plan_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/desks/plan", plan_desk_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/plan/dependencies/plan", plan_dependency_api, []}
    ].
