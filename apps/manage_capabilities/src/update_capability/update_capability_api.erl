-module(update_capability_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    MRI = cowboy_req:binding(mri, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"agent_identity">> := Agent} = Payload, Req1} ->
            Timestamp = erlang:system_time(millisecond),
            CmdMap = #{
                capability_mri => MRI,
                agent_identity => Agent,
                tags => maps:get(<<"tags">>, Payload, undefined),
                description => maps:get(<<"description">>, Payload, undefined),
                demo_procedure => maps:get(<<"demo_procedure">>, Payload, undefined),
                metadata => maps:get(<<"metadata">>, Payload, #{updated_at => Timestamp})
            },
            case update_capability_v1:new(CmdMap) of
                {ok, Cmd} ->
                    dispatch_result(maybe_update_capability:dispatch(Cmd), MRI, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end;
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"agent_identity required">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, MRI, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events, capability_mri => MRI}, Req);
dispatch_result({error, Reason}, _MRI, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
