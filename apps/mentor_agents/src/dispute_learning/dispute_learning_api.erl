-module(dispute_learning_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            CmdParams = #{
                learning_id => LearningId,
                reason => maps:get(<<"reason">>, Params, undefined)
            },
            dispatch_cmd(dispute_learning_v1, maybe_dispute_learning, CmdParams, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

dispatch_cmd(CmdMod, HandlerMod, CmdParams, Req) ->
    case CmdMod:new(CmdParams) of
        {ok, Cmd} ->
            dispatch_result(HandlerMod:dispatch(Cmd), Req);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
