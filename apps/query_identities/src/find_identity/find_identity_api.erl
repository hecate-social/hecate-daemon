-module(find_identity_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    case find_identity:execute(AgentIdentity) of
        {ok, Identity} ->
            hecate_api_utils:json_ok(#{identity => Identity}, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"identity_not_found">>, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
