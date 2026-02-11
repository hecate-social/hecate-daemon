-module(query_reputation_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/reputation/:agent_identity", get_reputation_api, []},
        {"/api/reputation/calls", get_rpc_calls_page_api, []},
        {"/api/reputation/disputes", get_disputes_page_api, []}
    ].
