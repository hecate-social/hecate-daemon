%%% @doc API handler: GET /api/torches
%%%
%%% List all torches with optional filters.
%%% Lives in the list_torches query spoke for vertical slicing.
%%% @end
-module(list_torches_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_torches:execute(Filters) of
        {ok, Torches} ->
            hecate_api_utils:json_ok(#{torches => Torches}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

build_filters(QS) ->
    lists:foldl(fun parse_filter/2, #{}, QS).

parse_filter({<<"status">>, V}, Acc) -> Acc#{status => V};
parse_filter({<<"name">>, V}, Acc) -> Acc#{name => V};
parse_filter({<<"include_archived">>, <<"true">>}, Acc) -> Acc#{include_archived => true};
parse_filter({<<"include_archived">>, <<"1">>}, Acc) -> Acc#{include_archived => true};
parse_filter({<<"limit">>, V}, Acc) -> maybe_int(limit, V, Acc);
parse_filter({<<"offset">>, V}, Acc) -> maybe_int(offset, V, Acc);
parse_filter(_, Acc) -> Acc.

maybe_int(Key, V, Acc) ->
    case catch binary_to_integer(V) of
        I when is_integer(I) -> Acc#{Key => I};
        _ -> Acc
    end.
