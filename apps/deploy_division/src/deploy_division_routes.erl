-module(deploy_division_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/start", start_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/pause", pause_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/resume", resume_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/complete", complete_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/archive", archive_deployment_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/releases/deploy", deploy_release_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/rollouts/stage", stage_rollout_api, []}
    ].
