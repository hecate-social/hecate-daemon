-module(revoke_ucan_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"DELETE">> -> handle_delete(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_delete(Req0, _State) ->
    CapId = cowboy_req:binding(capability_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"revoker">> := Revoker}, Req1} ->
            RevokedAt = erlang:system_time(millisecond),
            Cmd = revoke_ucan_v1:new(CapId, Revoker, RevokedAt),
            dispatch_result(maybe_revoke_ucan:dispatch(Cmd), Req1);
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"Missing revoker">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
