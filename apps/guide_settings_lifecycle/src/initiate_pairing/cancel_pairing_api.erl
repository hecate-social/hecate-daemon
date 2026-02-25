%%% @doc API handler: POST /api/pairing/cancel
%%%
%%% Cancels the current pairing session via hecate_pairing gen_server.
%%% @end
-module(cancel_pairing_api).
-export([init/2, routes/0]).

routes() -> [{"/api/pairing/cancel", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ok = hecate_pairing:cancel(),
    hecate_api_utils:json_ok(#{}, Req0).
