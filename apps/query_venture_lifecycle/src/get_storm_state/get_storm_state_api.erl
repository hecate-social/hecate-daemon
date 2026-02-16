%%% @doc API handler: GET /api/ventures/:venture_id/storm/state
-module(get_storm_state_api).
-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id/storm/state", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case get_storm_state:get(VentureId) of
        {ok, StormState} ->
            hecate_api_utils:json_ok(#{storm => StormState}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
