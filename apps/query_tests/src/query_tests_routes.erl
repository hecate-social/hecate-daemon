-module(query_tests_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/testing", get_testing_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/suites", get_test_suites_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/testing/results", get_test_results_page_api, []}
    ].
