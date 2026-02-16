%%% @doc API handler: GET /api/arcade/gladiators/stables/:stable_id/generations
%%% Returns generation-by-generation training history.
-module(get_training_history_api).

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id/generations", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            StableId = cowboy_req:binding(stable_id, Req0),
            {ok, Generations} = query_snake_gladiators_store:get_training_history(StableId),
            hecate_api_utils:json_ok(200, #{generations => Generations}, Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.
