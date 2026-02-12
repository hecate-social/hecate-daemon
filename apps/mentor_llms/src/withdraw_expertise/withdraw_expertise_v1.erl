%%% @doc withdraw_expertise_v1 command
%%% Withdraws expertise declaration for an agent.
-module(withdraw_expertise_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_agent_id/1]).

-record(withdraw_expertise_v1, {
    agent_id :: binary()
}).

-export_type([withdraw_expertise_v1/0]).
-opaque withdraw_expertise_v1() :: #withdraw_expertise_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, withdraw_expertise_v1()} | {error, term()}.
new(Params) ->
    AgentId = case maps:find(agent_id, Params) of
        {ok, V} -> V;
        error   -> hecate_identity:agent_id()
    end,
    Cmd = #withdraw_expertise_v1{agent_id = AgentId},
    validate(Cmd).

-spec validate(withdraw_expertise_v1()) -> {ok, withdraw_expertise_v1()} | {error, term()}.
validate(#withdraw_expertise_v1{agent_id = AId}) when not is_binary(AId) ->
    {error, invalid_agent_id};
validate(#withdraw_expertise_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(withdraw_expertise_v1()) -> map().
to_map(#withdraw_expertise_v1{} = Cmd) ->
    #{
        command_type => <<"withdraw_expertise">>,
        agent_id => Cmd#withdraw_expertise_v1.agent_id
    }.

-spec from_map(map()) -> {ok, withdraw_expertise_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_agent_id(#withdraw_expertise_v1{agent_id = V}) -> V.
