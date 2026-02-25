%%% @doc API handler: GET /api/pairing/status
%%%
%%% Returns current pairing session status from hecate_pairing gen_server.
%%% @end
-module(get_pairing_status_api).
-export([init/2, routes/0]).

routes() -> [{"/api/pairing/status", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Status = hecate_pairing:get_status(),
    hecate_api_utils:json_ok(Status, Req0).
