-module(get_capabilities_page_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QsVals = cowboy_req:parse_qs(Req0),
    Filters = build_filters(QsVals),
    case get_capabilities_page:execute(Filters) of
        {ok, Results} ->
            hecate_api_utils:json_ok(#{results => Results, count => length(Results)}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

build_filters(QsVals) ->
    lists:foldl(fun({K, V}, Acc) ->
        case K of
            <<"tag">> -> Acc#{tag => V};
            <<"agent_id">> -> Acc#{agent_id => V};
            <<"limit">> -> Acc#{limit => binary_to_integer(V)};
            <<"offset">> -> Acc#{offset => binary_to_integer(V)};
            _ -> Acc
        end
    end, #{}, QsVals).
