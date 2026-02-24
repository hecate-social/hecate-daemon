%%% @doc API handler: POST /api/settings/unpair
-module(unpair_node_api).
-export([init/2, routes/0]).

-dialyzer({nowarn_function, [handle_post/2]}).

routes() -> [{"/api/settings/unpair", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    Reason = maps:get(<<"reason">>, Decoded, <<"manual">>),
    UnpairedAt = erlang:system_time(millisecond),
    Cmd = unpair_node_v1:new(Reason, UnpairedAt),
    case maybe_unpair_node:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{unpaired => true}, Req1);
        {error, Reason2} ->
            hecate_api_utils:json_error(400, Reason2, Req1)
    end.
