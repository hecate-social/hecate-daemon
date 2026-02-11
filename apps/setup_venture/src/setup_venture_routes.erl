-module(setup_venture_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/setup", setup_venture_api, []},
        {"/api/ventures/:venture_id/vision/refine", refine_vision_api, []},
        {"/api/ventures/:venture_id/vision/submit", submit_vision_api, []},
        {"/api/ventures/:venture_id/archive", archive_venture_api, []}
    ].
