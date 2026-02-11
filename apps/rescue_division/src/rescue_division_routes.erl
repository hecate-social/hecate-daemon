-module(rescue_division_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/start", start_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/pause", pause_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/resume", resume_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/complete", complete_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/archive", archive_rescue_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/diagnoses/diagnose", diagnose_incident_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/fixes/apply", apply_fix_api, []}
    ].
