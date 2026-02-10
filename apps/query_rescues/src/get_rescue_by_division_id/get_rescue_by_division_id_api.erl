%%% @doc API handler: GET /api/divisions/:division_id/rescue
-module(get_rescue_by_division_id_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case get_rescue_by_division_id:get(DivisionId) of
        {ok, Rescue} ->
            hecate_api_utils:json_ok(#{rescue => Rescue}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Rescue not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
