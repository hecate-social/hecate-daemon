%%% @doc Cowboy route definitions for snake duel queries.
-module(query_snake_duel_routes).

-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/arcade/snake-duel/matches/:match_id/result", get_match_by_id_api, []},
        {"/api/arcade/snake-duel/history",                  get_match_history_api, []},
        {"/api/arcade/snake-duel/leaderboard",              get_leaderboard_api, []}
    ].
