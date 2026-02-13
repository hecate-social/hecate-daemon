%%% @doc API handler: GET /api/ventures/:venture_id/events
-module(get_venture_events_page_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    VentureId = cowboy_req:binding(venture_id, Req0),
    QsVals = cowboy_req:parse_qs(Req0),
    Offset = parse_int(proplists:get_value(<<"offset">>, QsVals, <<"0">>), 0),
    Limit = parse_int(proplists:get_value(<<"limit">>, QsVals, <<"50">>), 50),
    case get_venture_events_page:get(VentureId, Offset, Limit) of
        {ok, Result} ->
            hecate_api_utils:json_ok(Result, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

parse_int(Bin, Default) when is_binary(Bin) ->
    try binary_to_integer(Bin) catch _:_ -> Default end;
parse_int(_, Default) -> Default.
