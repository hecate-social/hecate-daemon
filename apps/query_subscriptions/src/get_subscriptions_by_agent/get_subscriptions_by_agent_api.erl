-module(get_subscriptions_by_agent_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    QsVals = cowboy_req:parse_qs(Req0),
    case proplists:get_value(<<"agent_identity">>, QsVals) of
        undefined ->
            hecate_api_utils:bad_request(<<"agent_identity query param required">>, Req0);
        AgentIdentity ->
            case get_subscriptions_by_agent:execute(AgentIdentity) of
                {ok, Subscriptions} ->
                    hecate_api_utils:json_ok(#{subscriptions => Subscriptions, count => length(Subscriptions)}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.
