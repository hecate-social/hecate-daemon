%%% @doc Cowboy route definitions for snake duel.
-module(run_snake_duel_routes).

-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/arcade/snake-duel/matches",            start_duel_api, []},
        {"/api/arcade/snake-duel/matches/:match_id/stream", stream_duel_api, []}
    ].
