%%% @doc API handler: POST /api/divisions/:division_id/plan/dependencies
-module(plan_dependency_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case DivisionId of
        undefined -> hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} -> do_plan_dependency(DivisionId, Params, Req1);
                {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_plan_dependency(DivisionId, Params, Req) ->
    CmdParams = #{
        division_id => DivisionId,
        from_desk => hecate_api_utils:get_field(from_desk, Params),
        to_desk => hecate_api_utils:get_field(to_desk, Params),
        dep_type => hecate_api_utils:get_field(dep_type, Params)
    },
    case plan_dependency_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_plan_dependency:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            emit_to_pg(EventMaps),
            hecate_api_utils:json_ok(201, #{
                division_id => plan_dependency_v1:get_division_id(Cmd),
                dependency_id => plan_dependency_v1:get_dependency_id(Cmd),
                events => EventMaps
            }, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_pg(EventMaps) ->
    lists:foreach(fun(E) -> dependency_planned_v1_to_pg:emit(E) end, EventMaps).
