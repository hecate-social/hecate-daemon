%%% @doc API handler: GET /api/node/ucan/verify/:capability_id
%%% Also supports: GET /api/node/ucan/verify?id=...
-module(verify_ucan_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    CapabilityId = resolve_capability_id(Req0),
    case CapabilityId of
        undefined ->
            hecate_api_utils:bad_request(
                <<"Missing capability_id binding or 'id' query parameter">>, Req0);
        Id ->
            case verify_ucan:get(Id) of
                {ok, Result} ->
                    hecate_api_utils:json_ok(Result, Req0);
                {error, not_found} ->
                    hecate_api_utils:json_error(404, <<"UCAN grant not found">>, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.

resolve_capability_id(Req) ->
    case cowboy_req:binding(capability_id, Req) of
        undefined ->
            QS = cowboy_req:parse_qs(Req),
            proplists:get_value(<<"id">>, QS);
        Id ->
            Id
    end.
