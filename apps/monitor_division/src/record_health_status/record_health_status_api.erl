-module(record_health_status_api).
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
    CheckId = maps:get(<<"check_id">>, Params, undefined),
    case CheckId of
        undefined ->
            hecate_api_utils:json_error(400, <<"check_id is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"check_id cannot be empty">>, Req1);
        _ ->
            Status = maps:get(<<"status">>, Params, <<"unknown">>),
            LatencyMs = maps:get(<<"latency_ms">>, Params, 0),
            Details = maps:get(<<"details">>, Params, undefined),
            case record_health_status_v1:new(#{
                division_id => DivisionId,
                check_id => CheckId,
                status => Status,
                latency_ms => LatencyMs,
                details => Details
            }) of
                {ok, Cmd} ->
                    case maybe_record_health_status:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            %% pg only — no mesh emitter for health status (too frequent)
                            lists:foreach(fun(E) ->
                                health_status_recorded_v1_to_pg:emit(E)
                            end, Events),
                            RespBody = #{
                                division_id => DivisionId,
                                check_id => CheckId,
                                version => Version,
                                events => Events
                            },
                            hecate_api_utils:json_reply(200, RespBody, Req1);
                        {error, Reason} ->
                            hecate_api_utils:json_error(422, Reason, Req1)
                    end;
                {error, Reason} ->
                    hecate_api_utils:json_error(400, Reason, Req1)
            end
    end.
