%%% @doc API handler: POST /api/ventures/:venture_id/vision/refine
%%%
%%% Iteratively refines a venture's vision.
%%% Dispatches through evoq -> venture_aggregate for state validation.
%%% @end
-module(refine_vision_api).

-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/vision/refine", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case VentureId of
        undefined ->
            hecate_api_utils:bad_request(<<"venture_id is required">>, Req0);
        _ ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} ->
                    do_refine(VentureId, Params, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_refine(VentureId, Params, Req) ->
    Brief = hecate_api_utils:get_field(brief, Params),
    Repos = hecate_api_utils:get_field(repos, Params),
    Skills = hecate_api_utils:get_field(skills, Params),
    ContextMap = hecate_api_utils:get_field(context_map, Params),

    CmdParams = #{
        venture_id => VentureId,
        brief => Brief,
        repos => Repos,
        skills => Skills,
        context_map => ContextMap
    },
    case refine_vision_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, VentureId, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, VentureId, Req) ->
    case maybe_refine_vision:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                venture_id => VentureId,
                refined => true,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
