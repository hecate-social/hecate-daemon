-module(get_endorsements_by_agent_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    QsVals = cowboy_req:parse_qs(Req0),
    QueryType = proplists:get_value(<<"type">>, QsVals, <<"given">>),
    Result = endorsements_query(QueryType, AgentIdentity),
    endorsements_result(Result, QueryType, Req0).

endorsements_query(<<"given">>, Agent) -> get_endorsements_by_agent:by_endorser(Agent);
endorsements_query(<<"received">>, Agent) -> get_endorsements_by_agent:by_capability_owner(Agent);
endorsements_query(_, Agent) -> get_endorsements_by_agent:by_endorser(Agent).

endorsements_result({ok, Endorsements}, QueryType, Req) ->
    hecate_api_utils:json_ok(#{
        endorsements => Endorsements,
        count => length(Endorsements),
        type => QueryType
    }, Req);
endorsements_result({error, Reason}, _, Req) ->
    hecate_api_utils:json_error(500, Reason, Req).
