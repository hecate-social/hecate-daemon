-module(announce_capability_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, #{<<"capability_mri">> := MRI, <<"agent_identity">> := Agent,
               <<"tags">> := Tags, <<"description">> := Desc} = Payload, Req1} ->
            Demo = maps:get(<<"demo_procedure">>, Payload, undefined),
            Metadata = maps:get(<<"metadata">>, Payload, #{}),
            Timestamp = erlang:system_time(millisecond),
            CmdMap = #{
                capability_mri => MRI,
                agent_identity => Agent,
                tags => Tags,
                description => Desc,
                demo_procedure => Demo,
                metadata => Metadata#{announced_at => Timestamp}
            },
            case announce_capability_v1:new(CmdMap) of
                {ok, Cmd} ->
                    dispatch_result(maybe_announce_capability:dispatch(Cmd), MRI, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end;
        {ok, _, Req1} ->
            hecate_api_utils:bad_request(<<"Missing required fields">>, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, MRI, Req) ->
    hecate_api_utils:json_ok(201, #{version => Version, events => Events, capability_mri => MRI}, Req);
dispatch_result({error, Reason}, _MRI, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
