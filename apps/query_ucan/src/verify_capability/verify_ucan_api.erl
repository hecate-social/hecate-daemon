-module(verify_ucan_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

%% GET /api/ucan/verify/:capability_id
handle_get(Req0, _State) ->
    CapabilityId = cowboy_req:binding(capability_id, Req0),
    verify_result(verify_capability:execute(CapabilityId), Req0).

%% POST /api/ucan/verify
handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"audience">> := Aud, <<"resource">> := Res, <<"action">> := Act}, Req1} ->
            verify_result(verify_capability:execute(Aud, Res, Act), Req1);
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"Missing audience, resource, or action">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

verify_result({ok, Validity, Capability}, Req) ->
    hecate_api_utils:json_ok(#{
        valid => Validity =:= valid,
        validity => atom_to_binary(Validity, utf8),
        capability => Capability
    }, Req);
verify_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(500, Reason, Req).
