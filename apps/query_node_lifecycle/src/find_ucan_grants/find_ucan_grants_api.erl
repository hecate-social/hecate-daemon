%%% @doc API handler: GET /api/node/ucan/grants
-module(find_ucan_grants_api).
-export([init/2]).

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
    case find_ucan_grants:get(Filters) of
        {ok, Grants} ->
            hecate_api_utils:json_ok(#{
                grants => Grants,
                count => length(Grants),
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
parse_filter({<<"issuer">>, V}, Acc) -> Acc#{issuer => V};
parse_filter({<<"audience">>, V}, Acc) -> Acc#{audience => V};
parse_filter({<<"active_only">>, <<"true">>}, Acc) -> Acc#{active_only => true};
parse_filter({<<"active_only">>, <<"1">>}, Acc) -> Acc#{active_only => true};
parse_filter(_, Acc) -> Acc.

maybe_int(Key, V, Acc) ->
    case catch binary_to_integer(V) of
        I when is_integer(I) -> Acc#{Key => I};
        _ -> Acc
    end.
