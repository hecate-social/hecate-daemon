%%% @doc API handler: DELETE /api/settings/api-keys/:provider
-module(remove_api_key_api).
-export([init/2, routes/0]).

-dialyzer({nowarn_function, [handle_delete/2]}).

routes() -> [{"/api/settings/api-keys/:provider", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"DELETE">> -> handle_delete(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_delete(Req0, _State) ->
    Provider = cowboy_req:binding(provider, Req0),
    RemovedAt = erlang:system_time(millisecond),
    Cmd = remove_api_key_v1:new(Provider, RemovedAt),
    case maybe_remove_api_key:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{removed => true, provider => Provider}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req0)
    end.
