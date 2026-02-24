%%% @doc API handler: POST /api/settings/api-keys
-module(configure_api_key_api).
-export([init/2, routes/0]).

-dialyzer({nowarn_function, [handle_post/2]}).

routes() -> [{"/api/settings/api-keys", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    Provider = maps:get(<<"provider">>, Decoded, <<>>),
    ApiKey = maps:get(<<"api_key">>, Decoded, <<>>),
    Label = maps:get(<<"label">>, Decoded, Provider),
    ConfiguredAt = erlang:system_time(millisecond),
    Cmd = configure_api_key_v1:new(Provider, ApiKey, Label, ConfiguredAt),
    case maybe_configure_api_key:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{configured => true, provider => Provider}, Req1);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.
