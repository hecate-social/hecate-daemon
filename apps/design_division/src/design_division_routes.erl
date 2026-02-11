-module(design_division_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/design/start", start_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/pause", pause_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/resume", resume_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/complete", complete_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/archive", archive_design_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/aggregates/design", design_aggregate_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/events/design", design_event_api, []}
    ].
