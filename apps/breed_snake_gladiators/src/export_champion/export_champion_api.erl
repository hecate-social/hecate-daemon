%%% @doc API handler: POST /api/arcade/gladiators/stables/:stable_id/export
%%% Exports the champion network from a completed stable.
%%% Returns the network JSON directly.
-module(export_champion_api).

-export([init/2, routes/0]).

routes() -> [{"/api/arcade/gladiators/stables/:stable_id/export", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            StableId = cowboy_req:binding(stable_id, Req0),
            handle_export(StableId, Req0);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

handle_export(StableId, Req) ->
    case query_snake_gladiators_store:get_champion(StableId) of
        {ok, Champion} ->
            hecate_api_utils:json_ok(200, Champion, Req);
        {error, not_found} ->
            hecate_api_utils:not_found(Req)
    end.
