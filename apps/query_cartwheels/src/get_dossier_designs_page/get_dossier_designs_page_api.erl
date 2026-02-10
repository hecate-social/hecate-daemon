%%% @doc API handler: GET /api/cartwheels/:cartwheel_id/architecture/dossiers
%%%
%%% List dossier designs for a cartwheel.
%%% @end
-module(get_dossier_designs_page_api).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    CartwheelId = cowboy_req:binding(cartwheel_id, Req0),
    Filters = parse_filters(Req0),
    case get_dossier_designs_page:execute(Filters#{cartwheel_id => CartwheelId}) of
        {ok, Dossiers} ->
            hecate_api_utils:json_ok(#{dossiers => Dossiers}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

parse_filters(Req) ->
    QS = cowboy_req:parse_qs(Req),
    lists:foldl(fun parse_filter/2, #{}, QS).

parse_filter({<<"limit">>, V}, Acc) -> maybe_int(limit, V, Acc);
parse_filter({<<"offset">>, V}, Acc) -> maybe_int(offset, V, Acc);
parse_filter(_, Acc) -> Acc.

maybe_int(Key, V, Acc) ->
    case catch binary_to_integer(V) of
        I when is_integer(I) -> Acc#{Key => I};
        _ -> Acc
    end.
