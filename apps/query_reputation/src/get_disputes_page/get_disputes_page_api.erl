-module(get_disputes_page_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QsVals = cowboy_req:parse_qs(Req0),
    AgentIdentity = proplists:get_value(<<"agent_identity">>, QsVals, undefined),
    StatusFilter = proplists:get_value(<<"status">>, QsVals, undefined),
    Query = get_disputes_page_v1:new(AgentIdentity, StatusFilter),
    case handle_get_disputes_page:handle(Query) of
        {ok, Disputes} ->
            hecate_api_utils:json_ok(#{disputes => Disputes, count => length(Disputes)}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
