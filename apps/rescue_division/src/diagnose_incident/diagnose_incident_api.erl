-module(diagnose_incident_api).
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
    IncidentId = maps:get(<<"incident_id">>, Params, undefined),
    Diagnosis = maps:get(<<"diagnosis">>, Params, undefined),
    RootCause = maps:get(<<"root_cause">>, Params, undefined),
    DiagnosedBy = maps:get(<<"diagnosed_by">>, Params, undefined),
    case diagnose_incident_v1:new(#{
        division_id => DivisionId,
        incident_id => IncidentId,
        diagnosis => Diagnosis,
        root_cause => RootCause,
        diagnosed_by => DiagnosedBy
    }) of
        {ok, Cmd} ->
            case maybe_diagnose_incident:dispatch(Cmd) of
                {ok, Version, Events} ->
                    DiagnosisId = extract_diagnosis_id(Events),
                    lists:foreach(fun(E) ->
                        incident_diagnosed_v1_to_pg:emit(E),
                        incident_diagnosed_v1_to_mesh:emit(E)
                    end, Events),
                    RespBody = #{
                        division_id => DivisionId,
                        diagnosis_id => DiagnosisId,
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

extract_diagnosis_id([#{<<"diagnosis_id">> := DiagnosisId} | _]) -> DiagnosisId;
extract_diagnosis_id([#{diagnosis_id := DiagnosisId} | _]) -> DiagnosisId;
extract_diagnosis_id(_) -> undefined.
