-module(query_monitoring_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring", get_monitoring_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/health-checks", get_health_checks_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/incidents", get_incidents_page_api, []}
    ].
