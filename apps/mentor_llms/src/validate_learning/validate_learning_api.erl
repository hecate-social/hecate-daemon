-module(validate_learning_api).
-export([init/2, routes/0]).

routes() -> [{"/api/mentors/learnings/:learning_id/validate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    CmdParams = #{learning_id => LearningId},
    case validate_learning_v1:new(CmdParams) of
        {ok, Cmd} ->
            dispatch_result(maybe_validate_learning:dispatch(Cmd), Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.

dispatch_result({ok, Version, Events}, Req) ->
    hecate_api_utils:json_ok(#{version => Version, events => Events}, Req);
dispatch_result({error, Reason}, Req) ->
    hecate_api_utils:json_error(400, Reason, Req).
