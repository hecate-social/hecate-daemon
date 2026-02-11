-module(query_generations_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/generation", get_generation_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/modules", get_generated_modules_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/generation/tests", get_generated_tests_page_api, []}
    ].
