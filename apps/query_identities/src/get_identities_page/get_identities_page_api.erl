-module(get_identities_page_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QsVals = cowboy_req:parse_qs(Req0),
    Limit = parse_int(proplists:get_value(<<"limit">>, QsVals), 100),
    Offset = parse_int(proplists:get_value(<<"offset">>, QsVals), 0),
    case get_identities_page:execute(#{limit => Limit, offset => Offset}) of
        {ok, Identities} ->
            hecate_api_utils:json_ok(#{
                identities => Identities,
                count => length(Identities),
                limit => Limit,
                offset => Offset
            }, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

parse_int(undefined, Default) -> Default;
parse_int(Bin, _Default) -> binary_to_integer(Bin).
