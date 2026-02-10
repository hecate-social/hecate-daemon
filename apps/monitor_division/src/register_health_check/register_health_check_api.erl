-module(register_health_check_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = json:decode(Body),
    CheckName = maps:get(<<"check_name">>, Params, undefined),
    case CheckName of
        undefined ->
            hecate_api_utils:json_error(400, <<"check_name is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"check_name cannot be empty">>, Req1);
        _ ->
            CheckType = maps:get(<<"check_type">>, Params, <<"http">>),
            Endpoint = maps:get(<<"endpoint">>, Params, <<>>),
            IntervalMs = maps:get(<<"interval_ms">>, Params, 30000),
            case register_health_check_v1:new(#{
                division_id => DivisionId,
                check_name => CheckName,
                check_type => CheckType,
                endpoint => Endpoint,
                interval_ms => IntervalMs
            }) of
                {ok, Cmd} ->
                    case maybe_register_health_check:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            CheckId = extract_check_id(Events),
                            lists:foreach(fun(E) ->
                                health_check_registered_v1_to_pg:emit(E),
                                health_check_registered_v1_to_mesh:emit(E)
                            end, Events),
                            RespBody = #{
                                division_id => DivisionId,
                                check_id => CheckId,
                                check_name => CheckName,
                                version => Version,
                                events => Events
                            },
                            hecate_api_utils:json_reply(201, RespBody, Req1);
                        {error, Reason} ->
                            hecate_api_utils:json_error(422, Reason, Req1)
                    end;
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end
    end.

extract_check_id([#{<<"check_id">> := CheckId} | _]) -> CheckId;
extract_check_id([#{check_id := CheckId} | _]) -> CheckId;
extract_check_id(_) -> undefined.
