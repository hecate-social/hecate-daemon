-module(apply_fix_api).
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
    DiagnosisId = maps:get(<<"diagnosis_id">>, Params, undefined),
    FixDescription = maps:get(<<"fix_description">>, Params, undefined),
    FixType = maps:get(<<"fix_type">>, Params, undefined),
    AppliedBy = maps:get(<<"applied_by">>, Params, undefined),
    case apply_fix_v1:new(#{
        division_id => DivisionId,
        incident_id => IncidentId,
        diagnosis_id => DiagnosisId,
        fix_description => FixDescription,
        fix_type => FixType,
        applied_by => AppliedBy
    }) of
        {ok, Cmd} ->
            case maybe_apply_fix:dispatch(Cmd) of
                {ok, Version, Events} ->
                    FixId = extract_fix_id(Events),
                    lists:foreach(fun(E) ->
                        fix_applied_v1_to_pg:emit(E),
                        fix_applied_v1_to_mesh:emit(E)
                    end, Events),
                    RespBody = #{
                        division_id => DivisionId,
                        fix_id => FixId,
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

extract_fix_id([#{<<"fix_id">> := FixId} | _]) -> FixId;
extract_fix_id([#{fix_id := FixId} | _]) -> FixId;
extract_fix_id(_) -> undefined.
