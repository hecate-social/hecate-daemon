-module(apply_fix_api).
-export([init/2]).
init(Req0, State) -> case cowboy_req:method(Req0) of <<"POST">> -> handle_post(Req0, State); _ -> hecate_api_utils:method_not_allowed(Req0) end.
handle_post(Req0, _State) ->
    DI = cowboy_req:binding(division_id, Req0),
    case DI of undefined -> hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ -> case hecate_api_utils:read_json_body(Req0) of {ok, P, R1} -> do_apply_fix(DI, P, R1); {error, invalid_json, R1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, R1) end end.
do_apply_fix(DI, P, Req) ->
    CP = #{division_id => DI, incident_id => hecate_api_utils:get_field(incident_id, P), description => hecate_api_utils:get_field(description, P)},
    case apply_fix_v1:new(CP) of {ok, Cmd} -> dispatch(Cmd, Req); {error, R} -> hecate_api_utils:bad_request(R, Req) end.
dispatch(Cmd, Req) ->
    case maybe_apply_fix:dispatch(Cmd) of
        {ok, _, EM} -> lists:foreach(fun(E) -> fix_applied_v1_to_pg:emit(E) end, EM), hecate_api_utils:json_ok(201, #{division_id => apply_fix_v1:get_division_id(Cmd), fix_id => apply_fix_v1:get_fix_id(Cmd), events => EM}, Req);
        {error, R} -> hecate_api_utils:bad_request(R, Req) end.
