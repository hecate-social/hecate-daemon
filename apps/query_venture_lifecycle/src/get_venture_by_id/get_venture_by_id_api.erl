%%% @doc API handler: GET /api/ventures/:venture_id
-module(get_venture_by_id_api).
-export([init/2, routes/0]).

routes() -> [{"/api/ventures/:venture_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    case get_venture_by_id:get(VentureId) of
        {ok, Venture} ->
            hecate_api_utils:json_ok(#{venture => Venture}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Venture not found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
