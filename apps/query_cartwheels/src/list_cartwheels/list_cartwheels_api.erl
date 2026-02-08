%%% @doc API handler: GET /api/cartwheels
%%%
%%% List all cartwheels with optional filters.
%%% @end
-module(list_cartwheels_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS),
    case list_cartwheels:execute(Filters) of
        {ok, Cartwheels} ->
            hecate_api_utils:json_ok(#{cartwheels => Cartwheels}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

build_filters(QS) ->
    lists:foldl(fun parse_filter/2, #{}, QS).

parse_filter({<<"torch_id">>, V}, Acc) -> Acc#{torch_id => V};
parse_filter({<<"current_phase">>, V}, Acc) -> Acc#{current_phase => V};
parse_filter({<<"limit">>, V}, Acc) -> maybe_int(limit, V, Acc);
parse_filter({<<"offset">>, V}, Acc) -> maybe_int(offset, V, Acc);
parse_filter(_, Acc) -> Acc.

maybe_int(Key, V, Acc) ->
    case catch binary_to_integer(V) of
        I when is_integer(I) -> Acc#{Key => I};
        _ -> Acc
    end.
