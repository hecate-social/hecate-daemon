-module(update_identity_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"metadata">> := Metadata}, Req1} ->
            Timestamp = erlang:system_time(millisecond),
            Cmd = update_identity_v1:new(AgentIdentity, Metadata, Timestamp),
            dispatch_result(maybe_update_identity:dispatch(Cmd), Req1);
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"Missing metadata">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
