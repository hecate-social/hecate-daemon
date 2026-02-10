%%% @doc API handler: GET /api/cartwheels/:cartwheel_id/deployment/deployments
%%%
%%% Lists deployments for a cartwheel.
%%% @end
-module(get_deployments_page_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QS, #{cartwheel_id => CartwheelId}),
    case get_deployments_page:execute(Filters) of
        {ok, Deployments} ->
            hecate_api_utils:json_ok(#{deployments => Deployments}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

build_filters(QS, Initial) ->
    lists:foldl(fun parse_filter/2, Initial, QS).

parse_filter({<<"environment">>, V}, Acc) -> Acc#{environment => V};
parse_filter({<<"limit">>, V}, Acc) -> maybe_int(limit, V, Acc);
parse_filter({<<"offset">>, V}, Acc) -> maybe_int(offset, V, Acc);
parse_filter(_, Acc) -> Acc.

maybe_int(Key, V, Acc) ->
    case catch binary_to_integer(V) of
        I when is_integer(I) -> Acc#{Key => I};
        _ -> Acc
    end.
