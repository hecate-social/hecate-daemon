-module(query_mentorships_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/mentors/learnings", get_learnings_page_api, []},
        {"/api/mentors/learnings/:learning_id", get_learning_by_id_api, []},
        {"/api/mentors/profiles", get_mentors_page_api, []},
        {"/api/mentors/profiles/:agent_id", get_mentor_profile_by_id_api, []},
        {"/api/mentors/subscriptions", get_subscriptions_page_api, []},
        {"/api/mentors/remote", get_remote_learnings_page_api, []}
    ].
