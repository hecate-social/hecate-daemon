%%% @doc API handler: GET /api/arcade/gladiators/stables/:stable_id/champions
%%%
%%% Returns all champions for a stable, ordered by rank.
%%% @end
-module(get_champions_api).

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id/champions", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            StableId = cowboy_req:binding(stable_id, Req0),
            {ok, Champions} = query_snake_gladiators_store:get_champions(StableId),
            hecate_api_utils:json_ok(200, #{ok => true, champions => Champions}, Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.
