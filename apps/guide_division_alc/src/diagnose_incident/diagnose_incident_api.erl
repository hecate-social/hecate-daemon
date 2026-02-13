-module(diagnose_incident_api).
-export([init/2]).
init(Req0, State) -> case cowboy_req:method(Req0) of <<"POST">> -> handle_post(Req0, State); _ -> hecate_api_utils:method_not_allowed(Req0) end.
handle_post(Req0, _State) ->
    DI = cowboy_req:binding(division_id, Req0),
    case DI of undefined -> hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ -> case hecate_api_utils:read_json_body(Req0) of {ok, P, R1} -> do_diagnose(DI, P, R1); {error, invalid_json, R1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, R1) end end.
do_diagnose(DI, P, Req) ->
    CP = #{division_id => DI, incident_id => hecate_api_utils:get_field(incident_id, P), root_cause => hecate_api_utils:get_field(root_cause, P)},
    case diagnose_incident_v1:new(CP) of {ok, Cmd} -> dispatch(Cmd, Req); {error, R} -> hecate_api_utils:bad_request(R, Req) end.
dispatch(Cmd, Req) ->
    case maybe_diagnose_incident:dispatch(Cmd) of
        {ok, _, EM} -> hecate_api_utils:json_ok(201, #{division_id => diagnose_incident_v1:get_division_id(Cmd), diagnosis_id => diagnose_incident_v1:get_diagnosis_id(Cmd), events => EM}, Req);
        {error, R} -> hecate_api_utils:bad_request(R, Req) end.
