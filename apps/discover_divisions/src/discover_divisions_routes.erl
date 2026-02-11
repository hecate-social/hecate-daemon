-module(discover_divisions_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/discovery/start", start_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/pause", pause_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/resume", resume_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/complete", complete_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/archive", archive_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/divisions/discover", discover_division_api, []}
    ].
