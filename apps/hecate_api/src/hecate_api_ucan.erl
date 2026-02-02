-module(hecate_api_ucan).

-export([init/2]).

init(Req0, [grant]) -> handle_grant(Req0);
init(Req0, [revoke]) -> handle_revoke(Req0);
init(Req0, [list]) -> handle_list(Req0);
init(Req0, [verify]) -> handle_verify(Req0);
init(Req0, [verify_action]) -> handle_verify_action(Req0).

%% POST /ucan/grant
handle_grant(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_grant(Decoded, Req1).

do_grant(#{<<"capability_id">> := CapId, <<"issuer">> := Issuer, <<"audience">> := Audience,
           <<"resource">> := Resource, <<"actions">> := Actions, <<"expires_at">> := ExpiresAt}, Req) ->
    GrantedAt = erlang:system_time(millisecond),
    Cmd = grant_capability_v1:new(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt),
    dispatch_result(maybe_grant_capability:dispatch(Cmd), 201, Req);
do_grant(_, Req) ->
    error_response(Req, 400, invalid_request_body).

%% DELETE /ucan/revoke/:capability_id
handle_revoke(Req0) ->
    CapabilityId = cowboy_req:binding(capability_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_revoke(CapabilityId, Decoded, Req1).

do_revoke(CapabilityId, #{<<"revoker">> := Revoker}, Req) ->
    RevokedAt = erlang:system_time(millisecond),
    Cmd = revoke_capability_v1:new(CapabilityId, Revoker, RevokedAt),
    dispatch_result(maybe_revoke_capability:dispatch(Cmd), 200, Req);
do_revoke(_, _, Req) ->
    error_response(Req, 400, revoker_required).

%% GET /ucan/capabilities?audience=...&issuer=...
handle_list(Req0) ->
    QsVals = cowboy_req:parse_qs(Req0),
    Audience = proplists:get_value(<<"audience">>, QsVals),
    Issuer = proplists:get_value(<<"issuer">>, QsVals),
    do_list(Audience, Issuer, Req0).

do_list(undefined, undefined, Req) ->
    error_response(Req, 400, audience_or_issuer_required);
do_list(Audience, undefined, Req) ->
    query_result(find_capabilities:by_audience(Audience), capabilities, Req);
do_list(undefined, Issuer, Req) ->
    query_result(find_capabilities:by_issuer(Issuer), capabilities, Req);
do_list(Audience, _, Req) ->
    query_result(find_capabilities:by_audience(Audience), capabilities, Req).

%% GET /ucan/verify/:capability_id
handle_verify(Req0) ->
    CapabilityId = cowboy_req:binding(capability_id, Req0),
    verify_result(verify_capability:execute(CapabilityId), Req0).

%% POST /ucan/verify - Verify capability by audience, resource, action
handle_verify_action(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    do_verify_action(Decoded, Req1).

do_verify_action(#{<<"audience">> := Aud, <<"resource">> := Res, <<"action">> := Act}, Req) ->
    verify_result(verify_capability:execute(Aud, Res, Act), Req);
do_verify_action(_, Req) ->
    error_response(Req, 400, invalid_request_body).

verify_result({ok, Validity, Capability}, Req) ->
    Response = json:encode(#{
        ok => true,
        valid => Validity =:= valid,
        validity => atom_to_binary(Validity, utf8),
        capability => Capability
    }),
    reply(200, Response, Req);
verify_result({error, Reason}, Req) ->
    error_response(Req, 500, Reason).

%% Internal helpers

dispatch_result({ok, Version, Events}, Status, Req) ->
    Response = json:encode(#{ok => true, version => Version, events => Events}),
    reply(Status, Response, Req);
dispatch_result({error, Reason}, _, Req) ->
    error_response(Req, 400, Reason).

query_result({ok, Items}, Key, Req) ->
    Response = json:encode(#{ok => true, Key => Items, count => length(Items)}),
    reply(200, Response, Req);
query_result({error, Reason}, _, Req) ->
    error_response(Req, 400, Reason).

reply(Status, Response, Req) ->
    Req2 = cowboy_req:reply(Status, #{<<"content-type">> => <<"application/json">>}, Response, Req),
    {ok, Req2, []}.

error_response(Req, StatusCode, Reason) ->
    Response = json:encode(#{ok => false, error => atom_to_binary(Reason, utf8)}),
    reply(StatusCode, Response, Req).
