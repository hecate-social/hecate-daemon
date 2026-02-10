-module(raise_incident_api).
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
    IncidentTitle = maps:get(<<"incident_title">>, Params, undefined),
    case IncidentTitle of
        undefined ->
            hecate_api_utils:json_error(400, <<"incident_title is required">>, Req1);
        <<>> ->
            hecate_api_utils:json_error(400, <<"incident_title cannot be empty">>, Req1);
        _ ->
            Severity = maps:get(<<"severity">>, Params, <<"medium">>),
            Description = maps:get(<<"description">>, Params, undefined),
            case raise_incident_v1:new(#{
                division_id => DivisionId,
                incident_title => IncidentTitle,
                severity => Severity,
                description => Description
            }) of
                {ok, Cmd} ->
                    case maybe_raise_incident:dispatch(Cmd) of
                        {ok, Version, Events} ->
                            IncidentId = extract_incident_id(Events),
                            lists:foreach(fun(E) ->
                                incident_raised_v1_to_pg:emit(E),
                                incident_raised_v1_to_mesh:emit(E)
                            end, Events),
                            RespBody = #{
                                division_id => DivisionId,
                                incident_id => IncidentId,
                                incident_title => IncidentTitle,
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

extract_incident_id([#{<<"incident_id">> := IncidentId} | _]) -> IncidentId;
extract_incident_id([#{incident_id := IncidentId} | _]) -> IncidentId;
extract_incident_id(_) -> undefined.
