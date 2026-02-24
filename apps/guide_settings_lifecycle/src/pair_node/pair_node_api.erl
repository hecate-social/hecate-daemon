%%% @doc API handler: POST /api/settings/pair
-module(pair_node_api).
-export([init/2, routes/0]).

-dialyzer({nowarn_function, [handle_post/2]}).

routes() -> [{"/api/settings/pair", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Decoded = json:decode(Body),
    GithubUser = maps:get(<<"github_user">>, Decoded, <<>>),
    Realm = maps:get(<<"realm">>, Decoded, <<"io.macula">>),
    PairedAt = erlang:system_time(millisecond),
    Cmd = pair_node_v1:new(GithubUser, Realm, PairedAt),
    case maybe_pair_node:dispatch(Cmd) of
        {ok, _Version, _Events} ->
            hecate_api_utils:json_ok(#{paired => true, github_user => GithubUser}, Req1);
        {error, Reason} ->
            hecate_api_utils:json_error(400, Reason, Req1)
    end.
