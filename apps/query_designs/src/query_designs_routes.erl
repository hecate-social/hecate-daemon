-module(query_designs_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/design", get_design_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/aggregates", get_designed_aggregates_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/design/events", get_designed_events_page_api, []}
    ].
