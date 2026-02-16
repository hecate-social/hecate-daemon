%%% @doc API handler: GET /api/arcade/gladiators/stables/:stable_id
%%% Returns a single stable by ID.
-module(get_stable_by_id_api).

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            StableId = cowboy_req:binding(stable_id, Req0),
            case query_snake_gladiators_store:get_stable_by_id(StableId) of
                {ok, Stable} ->
                    hecate_api_utils:json_ok(200, Stable, Req0);
                {error, not_found} ->
                    hecate_api_utils:not_found(Req0)
            end;
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.
