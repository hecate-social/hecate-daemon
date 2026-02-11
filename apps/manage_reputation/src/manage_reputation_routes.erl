-module(manage_reputation_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/rpc/track", track_rpc_call_api, []}
    ].
