-module(grant_ucan_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"capability_id">> := CapId, <<"issuer">> := Issuer, <<"audience">> := Audience,
               <<"resource">> := Resource, <<"actions">> := Actions, <<"expires_at">> := ExpiresAt}, Req1} ->
            GrantedAt = erlang:system_time(millisecond),
            Cmd = grant_capability_v1:new(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt),
            dispatch_result(maybe_grant_capability:dispatch(Cmd), Req1);
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"Missing required fields">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(201, #{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
