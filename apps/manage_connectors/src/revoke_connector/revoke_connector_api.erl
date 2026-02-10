-module(revoke_connector_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ConnId = cowboy_req:binding(connector_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            CmdParams = #{
                connector_id => ConnId,
                reason => maps:get(<<"reason">>, Params, <<"manual_revocation">>)
            },
            case revoke_connector_v1:new(CmdParams) of
                {ok, Cmd} ->
                    dispatch_result(maybe_revoke_connector:dispatch(Cmd), ConnId, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end;
        {error, invalid_json, Req1} ->
            %% Allow empty body
            CmdParams = #{
                connector_id => ConnId,
                reason => <<"manual_revocation">>
            },
            case revoke_connector_v1:new(CmdParams) of
                {ok, Cmd} ->
                    dispatch_result(maybe_revoke_connector:dispatch(Cmd), ConnId, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end
    end.

dispatch_result({ok, Version, Events}, ConnId, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events, connector_id => ConnId}, Req);
dispatch_result({error, Reason}, _ConnId, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
