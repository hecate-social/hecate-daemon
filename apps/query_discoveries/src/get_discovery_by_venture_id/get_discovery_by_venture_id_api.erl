%%% @doc API handler: GET /api/ventures/:venture_id/discovery
-module(get_discovery_by_venture_id_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case get_discovery_by_venture_id:execute(VentureId) of
        {ok, Discovery} ->
            hecate_api_utils:json_ok(#{discovery => Discovery}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Discovery not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
