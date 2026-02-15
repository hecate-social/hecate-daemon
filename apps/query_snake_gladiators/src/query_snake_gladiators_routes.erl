%%% @doc Cowboy route definitions for snake gladiator queries.
%%%
%%% NOTE: GET /stables (list) is served by breed_snake_gladiators'
%%% initiate_stable_api handler which dispatches by method (POST=create,
%%% GET=list). This avoids Cowboy's one-handler-per-path constraint.
-module(query_snake_gladiators_routes).

-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/arcade/gladiators/stables/:stable_id",              get_stable_by_id_api, []},
        {"/api/arcade/gladiators/stables/:stable_id/champion",     get_champion_api, []},
        {"/api/arcade/gladiators/stables/:stable_id/generations",  get_training_history_api, []}
    ].
