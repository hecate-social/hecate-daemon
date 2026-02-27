%%% @doc API handler: POST /api/realms/join/cancel
%%%
%%% Cancels the current realm join session via hecate_realm_session.
-module(cancel_realm_join_api).
-export([init/2, routes/0]).

routes() -> [{"/api/realms/join/cancel", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ok = hecate_realm_session:cancel(),
    hecate_api_utils:json_ok(#{}, Req0).
