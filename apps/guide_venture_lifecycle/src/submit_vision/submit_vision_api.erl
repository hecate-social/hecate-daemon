%%% @doc API handler: POST /api/ventures/:venture_id/vision/submit
%%%
%%% Finalizes a venture's vision.
%%% @end
-module(submit_vision_api).

-export([init/2]).

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
            do_submit(VentureId, Req0)
    end.

do_submit(VentureId, Req) ->
    CmdParams = #{venture_id => VentureId},
    case submit_vision_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, VentureId, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, VentureId, Req) ->
    case maybe_submit_vision:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            %% INTERNAL: Emit to pg for projections (intra-daemon)
            emit_to_pg(EventMaps),
            hecate_api_utils:json_ok(200, #{
                venture_id => VentureId,
                submitted => true,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

emit_to_pg(EventMaps) ->
    lists:foreach(fun(E) ->
        vision_submitted_v1_to_pg:emit(E)
    end, EventMaps).
