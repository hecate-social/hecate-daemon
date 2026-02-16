%%% @doc API handler: GET /api/node/subscriptions
-module(get_subscriptions_page_api).
-export([init/2, routes/0]).

routes() -> [{"/api/node/subscriptions", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS, #{}),
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),
    case get_subscriptions_page:get(Filters) of
        {ok, Subscriptions} ->
            hecate_api_utils:json_ok(#{
                subscriptions => Subscriptions,
                count => length(Subscriptions),
                limit => Limit,
                offset => Offset
            }, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

build_filters(QS, Acc) ->
    lists:foldl(fun parse_filter/2, Acc, QS).

parse_filter({<<"limit">>, V}, Acc) -> maybe_int(limit, V, Acc);
parse_filter({<<"offset">>, V}, Acc) -> maybe_int(offset, V, Acc);
parse_filter(_, Acc) -> Acc.

maybe_int(Key, V, Acc) ->
    case catch binary_to_integer(V) of
        I when is_integer(I) -> Acc#{Key => I};
        _ -> Acc
    end.
