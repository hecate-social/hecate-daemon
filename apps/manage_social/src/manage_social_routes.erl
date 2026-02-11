-module(manage_social_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/social/follow", follow_agent_api, []},
        {"/api/social/unfollow", unfollow_agent_api, []},
        {"/api/social/endorse", endorse_capability_api, []},
        {"/api/social/endorsements/revoke", revoke_endorsement_api, []}
    ].
