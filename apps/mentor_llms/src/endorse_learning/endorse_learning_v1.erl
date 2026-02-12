%%% @doc endorse_learning_v1 command
%%% Endorses a validated learning.
-module(endorse_learning_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_learning_id/1, get_agent_id/1]).

-record(endorse_learning_v1, {
    learning_id :: binary(),
    agent_id    :: binary()
}).

-export_type([endorse_learning_v1/0]).
-opaque endorse_learning_v1() :: #endorse_learning_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, endorse_learning_v1()} | {error, term()}.
new(#{learning_id := LId} = Params) ->
    AgentId = case maps:find(agent_id, Params) of
        {ok, V} -> V;
        error   -> hecate_identity:agent_id()
    end,
    Cmd = #endorse_learning_v1{
        learning_id = LId,
        agent_id = AgentId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(endorse_learning_v1()) -> {ok, endorse_learning_v1()} | {error, term()}.
validate(#endorse_learning_v1{learning_id = LId}) when not is_binary(LId) ->
    {error, invalid_learning_id};
validate(#endorse_learning_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(endorse_learning_v1()) -> map().
to_map(#endorse_learning_v1{} = Cmd) ->
    #{
        command_type => <<"endorse_learning">>,
        learning_id => Cmd#endorse_learning_v1.learning_id,
        agent_id => Cmd#endorse_learning_v1.agent_id
    }.

-spec from_map(map()) -> {ok, endorse_learning_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_learning_id(#endorse_learning_v1{learning_id = V}) -> V.
get_agent_id(#endorse_learning_v1{agent_id = V}) -> V.
