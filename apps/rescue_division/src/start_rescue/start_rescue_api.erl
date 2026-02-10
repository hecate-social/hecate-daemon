-module(start_rescue_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Params = case Body of
        <<>> -> #{};
        _ -> json:decode(Body)
    end,
    IncidentId = maps:get(<<"incident_id">>, Params, undefined),
    StartedBy = maps:get(<<"started_by">>, Params, undefined),
    case start_rescue_v1:new(#{division_id => DivisionId, incident_id => IncidentId, started_by => StartedBy}) of
        {ok, Cmd} ->
            case maybe_start_rescue:dispatch(Cmd) of
                {ok, Version, Events} ->
                    lists:foreach(fun(E) ->
                        rescue_started_v1_to_pg:emit(E),
                        rescue_started_v1_to_mesh:emit(E)
                    end, Events),
                    RespBody = #{
                        division_id => DivisionId,
                        incident_id => IncidentId,
                        version => Version,
                        events => Events
                    },
                    hecate_api_utils:json_reply(201, RespBody, Req1);
                {error, Reason} ->
                    hecate_api_utils:json_error(422, Reason, Req1)
            end;
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.
