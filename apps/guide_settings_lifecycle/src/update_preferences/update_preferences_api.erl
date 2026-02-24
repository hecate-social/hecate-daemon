%%% @doc API handler: PUT /api/settings/preferences
-module(update_preferences_api).
-export([init/2, routes/0]).

-dialyzer({nowarn_function, [handle_put/2]}).

routes() -> [{"/api/settings/preferences", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"PUT">> -> handle_put(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_put(Req0, _State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    Preferences = maps:get(<<"preferences">>, Decoded, #{}),
    UpdatedAt = erlang:system_time(millisecond),
    Cmd = update_preferences_v1:new(Preferences, UpdatedAt),
    case maybe_update_preferences:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{updated => true}, Req1);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.
