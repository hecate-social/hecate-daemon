-module(query_deployments_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/ventures/:venture_id/divisions/:division_id/deployment", get_deployment_by_division_id_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/releases", get_releases_page_api, []},
        {"/api/ventures/:venture_id/divisions/:division_id/deployment/rollouts", get_rollout_stages_page_api, []}
    ].
