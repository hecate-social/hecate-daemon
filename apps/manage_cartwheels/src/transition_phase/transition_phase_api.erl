%%% @doc API handler: POST /api/cartwheels/:cartwheel_id/transition
%%%
%%% Transitions a cartwheel from one ALC phase to another.
%%% @end
-module(transition_phase_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} -> do_transition(Params, Req1);
        {error, invalid_json, Req1} -> hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_transition(Params, Req) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req),
    CmdParams = #{
        cartwheel_id => CartwheelId,
        from_phase => hecate_api_utils:get_field(from_phase, Params),
        to_phase => hecate_api_utils:get_field(to_phase, Params)
    },
    dispatch(transition_phase_v1, maybe_transition_phase, CmdParams, Req).

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
