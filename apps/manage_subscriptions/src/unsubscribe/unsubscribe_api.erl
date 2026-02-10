-module(unsubscribe_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"agent_identity">> := Agent, <<"topic">> := Topic}, Req1} ->
            Timestamp = erlang:system_time(millisecond),
            Cmd = unsubscribe_v1:new(Agent, Topic, Timestamp),
            dispatch_result(maybe_unsubscribe:dispatch(Cmd), Req1);
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"Missing agent_identity or topic">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
