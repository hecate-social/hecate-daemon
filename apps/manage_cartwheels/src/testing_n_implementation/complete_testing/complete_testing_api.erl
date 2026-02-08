%%% @doc API handler: POST /api/cartwheels/:cartwheel_id/testing/complete
%%%
%%% Completes the Testing & Implementation phase.
%%% @end
-module(complete_testing_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    CmdParams = #{cartwheel_id => CartwheelId},
    dispatch(CmdParams, Req0).

dispatch(CmdParams, Req) ->
    case complete_testing_v1:new(CmdParams) of
        {ok, Cmd} ->
            do_dispatch(Cmd, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

do_dispatch(Cmd, Req) ->
    case maybe_complete_testing:dispatch(Cmd) of
        {ok, Version, Events} ->
            hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
