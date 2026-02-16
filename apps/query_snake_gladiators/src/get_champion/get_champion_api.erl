%%% @doc API handler: GET /api/arcade/gladiators/stables/:stable_id/champion
%%% Returns the champion network for a completed stable.
-module(get_champion_api).

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id/champion", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            StableId = cowboy_req:binding(stable_id, Req0),
            case query_snake_gladiators_store:get_champion(StableId) of
                {ok, Champion} ->
                    hecate_api_utils:json_ok(200, Champion, Req0);
                {error, not_found} ->
                    hecate_api_utils:not_found(Req0)
            end;
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.
