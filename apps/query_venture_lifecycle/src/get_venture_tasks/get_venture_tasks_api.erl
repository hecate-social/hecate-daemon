%%% @doc API handler: GET /api/ventures/:venture_id/tasks
-module(get_venture_tasks_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case get_venture_tasks:get(VentureId) of
        {ok, Result} ->
            hecate_api_utils:json_ok(Result, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Venture not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
