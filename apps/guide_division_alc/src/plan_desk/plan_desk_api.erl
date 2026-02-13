%%% @doc API handler: POST /api/divisions/:division_id/plan/desks
-module(plan_desk_api).
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
                {ok, Params, Req1} -> do_plan_desk(DivisionId, Params, Req1);
                {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_plan_desk(DivisionId, Params, Req) ->
    CmdParams = #{
        division_id => DivisionId,
        desk_name => hecate_api_utils:get_field(desk_name, Params),
        description => hecate_api_utils:get_field(description, Params),
        department => hecate_api_utils:get_field(department, Params),
        commands => hecate_api_utils:get_field(commands, Params)
    },
    case plan_desk_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_plan_desk:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                division_id => plan_desk_v1:get_division_id(Cmd),
                desk_name => plan_desk_v1:get_desk_name(Cmd),
                events => EventMaps
            }, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.
