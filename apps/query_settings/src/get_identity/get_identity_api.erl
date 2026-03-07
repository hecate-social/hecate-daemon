%%% @doc API handler: GET /api/settings/identity
-module(get_identity_api).
-export([init/2, routes/0]).

routes() -> [{"/api/settings/identity", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case project_settings_store:get_identity() of
        {ok, Identity} ->
            hecate_api_utils:json_ok(#{identity => Identity}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"Settings not initialized">>, Req0)
    end.
