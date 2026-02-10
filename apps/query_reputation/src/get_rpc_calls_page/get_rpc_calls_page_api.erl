-module(get_rpc_calls_page_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QsVals = cowboy_req:parse_qs(Req0),
    AgentIdentity = proplists:get_value(<<"agent_identity">>, QsVals),
    SuccessFilter = case proplists:get_value(<<"success">>, QsVals) of
        <<"true">> -> true;
        <<"false">> -> false;
        _ -> undefined
    end,
    Limit = binary_to_integer(proplists:get_value(<<"limit">>, QsVals, <<"50">>)),
    Query = get_rpc_calls_page_v1:new(AgentIdentity, Limit, SuccessFilter),
    case handle_get_rpc_calls_page:handle(Query) of
        {ok, Calls} ->
            hecate_api_utils:json_ok(#{calls => Calls, count => length(Calls)}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
