-module(get_social_graph_api).
-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    AgentIdentity = cowboy_req:binding(agent_identity, Req0),
    QsVals = cowboy_req:parse_qs(Req0),
    Limit = parse_int(proplists:get_value(<<"limit">>, QsVals), 100),
    Opts = #{limit_per_section => Limit},
    {ok, Graph} = get_social_graph:execute(AgentIdentity, Opts),
    hecate_api_utils:json_ok(#{graph => Graph}, Req0).

parse_int(undefined, Default) -> Default;
parse_int(Bin, _Default) -> binary_to_integer(Bin).
