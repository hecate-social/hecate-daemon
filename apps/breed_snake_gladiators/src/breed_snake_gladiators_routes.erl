%%% @doc Cowboy route definitions for snake gladiator breeding.
-module(breed_snake_gladiators_routes).

-export([routes/0]).

-spec routes() -> [cowboy_router:route_match()].
routes() ->
    [
        {"/api/arcade/gladiators/stables",                        initiate_stable_api, []},
        {"/api/arcade/gladiators/stables/:stable_id/halt",        halt_training_api, []},
        {"/api/arcade/gladiators/stables/:stable_id/export",      export_champion_api, []},
        {"/api/arcade/gladiators/stables/:stable_id/stream",      stream_training_api, []},
        {"/api/arcade/gladiators/stables/:stable_id/duel",        start_champion_duel_api, []}
    ].
