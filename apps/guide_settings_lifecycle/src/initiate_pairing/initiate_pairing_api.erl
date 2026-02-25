%%% @doc API handler: POST /api/pairing/initiate
%%%
%%% Starts a new pairing session via hecate_pairing gen_server.
%%% @end
-module(initiate_pairing_api).
-export([init/2, routes/0]).

routes() -> [{"/api/pairing/initiate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_pairing:start_pairing() of
        {ok, SessionData} ->
            hecate_api_utils:json_ok(SessionData, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
