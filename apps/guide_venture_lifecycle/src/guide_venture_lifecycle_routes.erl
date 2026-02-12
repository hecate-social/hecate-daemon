-module(guide_venture_lifecycle_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        %% Inception
        {"/api/ventures/initiate", initiate_venture_api, []},
        {"/api/ventures/:venture_id/vision/refine", refine_vision_api, []},
        {"/api/ventures/:venture_id/vision/submit", submit_vision_api, []},
        %% Discovery
        {"/api/ventures/:venture_id/discovery/start", start_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/identify", identify_division_api, []},
        {"/api/ventures/:venture_id/discovery/pause", pause_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/resume", resume_discovery_api, []},
        {"/api/ventures/:venture_id/discovery/complete", complete_discovery_api, []},
        %% Archive
        {"/api/ventures/:venture_id/archive", archive_venture_api, []}
    ].
