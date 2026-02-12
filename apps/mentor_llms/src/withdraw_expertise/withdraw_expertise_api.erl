-module(withdraw_expertise_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case withdraw_expertise_v1:new(#{}) of
        {ok, Cmd} ->
            dispatch_result(maybe_withdraw_expertise:dispatch(Cmd), Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
