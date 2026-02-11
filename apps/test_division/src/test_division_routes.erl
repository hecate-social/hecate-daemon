-module(test_division_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/testing/start", start_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/pause", pause_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/resume", resume_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/complete", complete_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/archive", archive_testing_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/suites/run", run_test_suite_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/results/record", record_test_result_api, []}
    ].
