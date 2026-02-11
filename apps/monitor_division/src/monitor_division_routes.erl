-module(monitor_division_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/start", start_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/pause", pause_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/resume", resume_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/complete", complete_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/archive", archive_monitoring_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/health-checks/register", register_health_check_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/health-status/record", record_health_status_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/monitoring/incidents/raise", raise_incident_api, []}
    ].
