-module(query_social_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/social/followers/:agent_identity", get_followers_by_agent_api, []},
        {"/api/social/following/:agent_identity", get_following_by_agent_api, []},
        {"/api/social/endorsements/:agent_identity", get_endorsements_by_agent_api, []},
        {"/api/social/graph/:agent_identity", get_social_graph_api, []}
    ].
