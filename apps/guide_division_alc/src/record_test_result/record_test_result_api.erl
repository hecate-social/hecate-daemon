%%% @doc API handler: POST /api/divisions/:division_id/test/results
-module(record_test_result_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of <<"POST">> -> handle_post(Req0, State); _ -> hecate_api_utils:method_not_allowed(Req0) end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case DivisionId of
        undefined -> hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ -> case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} -> do_record(DivisionId, Params, Req1);
                {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1) end
    end.

do_record(DivisionId, Params, Req) ->
    CmdParams = #{division_id => DivisionId, suite_id => hecate_api_utils:get_field(suite_id, Params),
        passed => hecate_api_utils:get_field(passed, Params), failed => hecate_api_utils:get_field(failed, Params)},
    case record_test_result_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req) end.

dispatch(Cmd, Req) ->
    case maybe_record_test_result:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            emit_to_pg(EventMaps),
            hecate_api_utils:json_ok(201, #{division_id => record_test_result_v1:get_division_id(Cmd),
                result_id => record_test_result_v1:get_result_id(Cmd), events => EventMaps}, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req) end.

emit_to_pg(EventMaps) -> lists:foreach(fun(E) -> test_result_recorded_v1_to_pg:emit(E) end, EventMaps).
