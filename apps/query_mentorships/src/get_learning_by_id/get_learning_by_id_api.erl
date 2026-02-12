-module(get_learning_by_id_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    LearningId = cowboy_req:binding(learning_id, Req0),
    case get_learning_by_id:execute(LearningId) of
        {ok, Learning} ->
            hecate_api_utils:json_ok(#{learning => Learning}, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
