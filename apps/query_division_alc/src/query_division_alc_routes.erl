%%% @doc Routes for query_division_alc query desks.
-module(query_division_alc_routes).
-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/divisions", get_divisions_page_api, []},
        {"/api/divisions/:division_id", get_division_by_id_api, []},
        {"/api/divisions/by-venture/:venture_id", get_divisions_by_venture_api, []}
    ].
