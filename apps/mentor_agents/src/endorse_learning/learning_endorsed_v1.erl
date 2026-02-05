%%% @doc learning_endorsed_v1 event
%%% Emitted when a validated learning is endorsed.
-module(learning_endorsed_v1).

-export([new/2, to_map/1, from_map/1]).
-export([get_learning_id/1, get_agent_id/1, get_endorsed_at/1]).

-record(learning_endorsed_v1, {
    learning_id :: binary(),
    agent_id    :: binary(),
    endorsed_at :: integer()
}).

-export_type([learning_endorsed_v1/0]).
-opaque learning_endorsed_v1() :: #learning_endorsed_v1{}.

-spec new(binary(), binary()) -> learning_endorsed_v1().
new(LearningId, AgentId) ->
    #learning_endorsed_v1{
        learning_id = LearningId,
        agent_id = AgentId,
        endorsed_at = erlang:system_time(millisecond)
    }.

-spec to_map(learning_endorsed_v1()) -> map().
to_map(#learning_endorsed_v1{} = E) ->
    #{
        event_type => <<"learning_endorsed_v1">>,
        learning_id => E#learning_endorsed_v1.learning_id,
        agent_id => E#learning_endorsed_v1.agent_id,
        endorsed_at => E#learning_endorsed_v1.endorsed_at
    }.

-spec from_map(map()) -> {ok, learning_endorsed_v1()} | {error, term()}.
from_map(#{learning_id := LId, agent_id := AId} = Map) ->
    {ok, #learning_endorsed_v1{
        learning_id = LId,
        agent_id = AId,
        endorsed_at = maps:get(endorsed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_learning_id(#learning_endorsed_v1{learning_id = V}) -> V.
get_agent_id(#learning_endorsed_v1{agent_id = V}) -> V.
get_endorsed_at(#learning_endorsed_v1{endorsed_at = V}) -> V.
