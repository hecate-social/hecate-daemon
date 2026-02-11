-module(generate_division_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/generation/start", start_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/pause", pause_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/resume", resume_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/complete", complete_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/archive", archive_generation_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/modules/generate", generate_module_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/tests/generate", generate_test_api, []}
    ].
