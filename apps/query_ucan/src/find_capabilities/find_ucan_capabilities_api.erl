-module(find_ucan_capabilities_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QsVals = cowboy_req:parse_qs(Req0),
    Audience = proplists:get_value(<<"audience">>, QsVals),
    Issuer = proplists:get_value(<<"issuer">>, QsVals),
    do_query(Audience, Issuer, Req0).

do_query(undefined, undefined, Req) ->
    hecate_api_utils:bad_request(<<"audience or issuer query param required">>, Req);
do_query(Audience, undefined, Req) ->
    query_result(find_capabilities:by_audience(Audience), Req);
do_query(undefined, Issuer, Req) ->
    query_result(find_capabilities:by_issuer(Issuer), Req);
do_query(Audience, _, Req) ->
    query_result(find_capabilities:by_audience(Audience), Req).

query_result({ok, Capabilities}, Req) ->
    hecate_api_utils:json_ok(#{capabilities => Capabilities, count => length(Capabilities)}, Req);
query_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
