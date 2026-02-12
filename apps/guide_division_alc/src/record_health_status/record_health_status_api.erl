-module(record_health_status_api).
-export([init/2]).
init(Req0, State) -> case cowboy_req:method(Req0) of <<"POST">> -> handle_post(Req0, State); _ -> hecate_api_utils:method_not_allowed(Req0) end.
handle_post(Req0, _State) ->
    DI = cowboy_req:binding(division_id, Req0),
    case DI of undefined -> hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ -> case hecate_api_utils:read_json_body(Req0) of {ok, P, R1} -> do_record(DI, P, R1); {error, invalid_json, R1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, R1) end end.
do_record(DI, P, Req) ->
    CP = #{division_id => DI, check_id => hecate_api_utils:get_field(check_id, P), status => hecate_api_utils:get_field(status, P)},
    case record_health_status_v1:new(CP) of {ok, Cmd} -> dispatch(Cmd, Req); {error, R} -> hecate_api_utils:bad_request(R, Req) end.
dispatch(Cmd, Req) ->
    case maybe_record_health_status:dispatch(Cmd) of
        {ok, _, EM} -> lists:foreach(fun(E) -> health_status_recorded_v1_to_pg:emit(E) end, EM), hecate_api_utils:json_ok(200, #{division_id => record_health_status_v1:get_division_id(Cmd), check_id => record_health_status_v1:get_check_id(Cmd), events => EM}, Req);
        {error, R} -> hecate_api_utils:bad_request(R, Req) end.
