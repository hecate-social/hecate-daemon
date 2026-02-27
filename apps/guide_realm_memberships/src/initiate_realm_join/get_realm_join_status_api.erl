%%% @doc API handler: GET /api/realms/join/status
%%%
%%% Returns current realm join session status from hecate_realm_session.
-module(get_realm_join_status_api).
-export([init/2, routes/0]).

routes() -> [{"/api/realms/join/status", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    Status = hecate_realm_session:get_status(),
    hecate_api_utils:json_ok(Status, Req0).
