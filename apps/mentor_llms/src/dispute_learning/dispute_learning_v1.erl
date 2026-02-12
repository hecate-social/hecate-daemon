%%% @doc dispute_learning_v1 command
%%% Disputes a validated learning.
-module(dispute_learning_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_learning_id/1, get_agent_id/1, get_reason/1]).

-record(dispute_learning_v1, {
    learning_id :: binary(),
    agent_id    :: binary(),
    reason      :: binary() | undefined
}).

-export_type([dispute_learning_v1/0]).
-opaque dispute_learning_v1() :: #dispute_learning_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, dispute_learning_v1()} | {error, term()}.
new(#{learning_id := LId} = Params) ->
    AgentId = case maps:find(agent_id, Params) of
        {ok, V} -> V;
        error   -> hecate_identity:agent_id()
    end,
    Cmd = #dispute_learning_v1{
        learning_id = LId,
        agent_id = AgentId,
        reason = maps:get(reason, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(dispute_learning_v1()) -> {ok, dispute_learning_v1()} | {error, term()}.
validate(#dispute_learning_v1{learning_id = LId}) when not is_binary(LId) ->
    {error, invalid_learning_id};
validate(#dispute_learning_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(dispute_learning_v1()) -> map().
to_map(#dispute_learning_v1{} = Cmd) ->
    #{
        command_type => <<"dispute_learning">>,
        learning_id => Cmd#dispute_learning_v1.learning_id,
        agent_id => Cmd#dispute_learning_v1.agent_id,
        reason => Cmd#dispute_learning_v1.reason
    }.

-spec from_map(map()) -> {ok, dispute_learning_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_learning_id(#dispute_learning_v1{learning_id = V}) -> V.
get_agent_id(#dispute_learning_v1{agent_id = V}) -> V.
get_reason(#dispute_learning_v1{reason = V}) -> V.
