%%% @doc API handler: POST /api/cartwheels/:cartwheel_id/architecture/plan
%%%
%%% Drafts a plan during the architecture phase.
%%% @end
-module(draft_plan_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} -> do_draft(Params, Req1);
        {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_draft(Params, Req) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        title => hecate_api_utils:get_field(title, Params),
        content_ref => hecate_api_utils:get_field(content_ref, Params)
    },
    dispatch(draft_plan_v1, maybe_draft_plan, CmdParams, Req).

dispatch(CmdMod, HandlerMod, CmdParams, Req) ->
    case CmdMod:new(CmdParams) of
        {ok, Cmd} -> do_dispatch(HandlerMod, Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

do_dispatch(HandlerMod, Cmd, Req) ->
    case HandlerMod:dispatch(Cmd) of
        {ok, Version, Events} ->
            hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
