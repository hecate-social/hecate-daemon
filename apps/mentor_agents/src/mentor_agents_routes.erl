-module(mentor_agents_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/mentors/learnings/submit", submit_learning_api, []},
        {"/api/mentors/learnings/:learning_id/validate", validate_learning_api, []},
        {"/api/mentors/learnings/:learning_id/reject", reject_learning_api, []},
        {"/api/mentors/learnings/:learning_id/endorse", endorse_learning_api, []},
        {"/api/mentors/learnings/:learning_id/dispute", dispute_learning_api, []},
        {"/api/mentors/learnings/:learning_id/resolve", resolve_learning_dispute_api, []},
        {"/api/mentors/expertise", declare_expertise_api, []},
        {"/api/mentors/expertise/withdraw", withdraw_expertise_api, []},
        {"/api/mentors/subscribe", subscribe_to_mentor_api, []},
        {"/api/mentors/unsubscribe", unsubscribe_from_mentor_api, []}
    ].
