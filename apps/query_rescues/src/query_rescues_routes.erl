-module(query_rescues_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/rescue", get_rescue_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/diagnoses", get_diagnoses_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/rescue/fixes", get_fixes_page_api, []}
    ].
