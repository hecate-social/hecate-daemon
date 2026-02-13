%%% @doc API handler: POST /api/divisions/:division_id/generate/tests
-module(generate_test_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of <<"POST">> -> handle_post(Req0, State); _ -> hecate_api_utils:method_not_allowed(Req0) end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case DivisionId of
        undefined -> hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ -> case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} -> do_generate(DivisionId, Params, Req1);
                {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1) end
    end.

do_generate(DivisionId, Params, Req) ->
    CmdParams = #{division_id => DivisionId, test_name => hecate_api_utils:get_field(test_name, Params),
        module_name => hecate_api_utils:get_field(module_name, Params), path => hecate_api_utils:get_field(path, Params)},
    case generate_test_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req) end.

dispatch(Cmd, Req) ->
    case maybe_generate_test:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{division_id => generate_test_v1:get_division_id(Cmd),
                test_name => generate_test_v1:get_test_name(Cmd), events => EventMaps}, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req) end.
