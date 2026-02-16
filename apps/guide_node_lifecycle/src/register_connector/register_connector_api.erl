-module(register_connector_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/connectors/register", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            ConnId = maps:get(<<"connector_id">>, Params, undefined),
            Name = maps:get(<<"name">>, Params, undefined),
            AllowedRoutesRaw = maps:get(<<"allowed_routes">>, Params, <<"all">>),
            AllowedRoutes = case AllowedRoutesRaw of
                <<"all">> -> all;
                Routes when is_list(Routes) -> Routes;
                _ -> all
            end,
            CmdParams = #{
                connector_id => ConnId,
                name => Name,
                allowed_routes => AllowedRoutes,
                metadata => maps:get(<<"metadata">>, Params, #{})
            },
            case register_connector_v1:new(CmdParams) of
                {ok, Cmd} ->
                    dispatch_result(maybe_register_connector:dispatch(Cmd), ConnId, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end;
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_result({ok, Version, Events}, ConnId, Req) ->
    hecate_api_utils:json_ok(201, #{version => Version, events => Events, connector_id => ConnId}, Req);
dispatch_result({error, Reason}, _ConnId, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
