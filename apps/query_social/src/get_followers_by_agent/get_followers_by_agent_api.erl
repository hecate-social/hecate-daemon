-module(get_followers_by_agent_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    case get_followers_by_agent:execute(AgentIdentity) of
        {ok, Followers} ->
            hecate_api_utils:json_ok(#{followers => Followers, count => length(Followers)}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
