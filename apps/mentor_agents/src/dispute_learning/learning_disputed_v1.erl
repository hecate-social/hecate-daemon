%%% @doc learning_disputed_v1 event
%%% Emitted when a validated learning is disputed.
-module(learning_disputed_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_learning_id/1, get_agent_id/1, get_reason/1, get_disputed_at/1]).

-record(learning_disputed_v1, {
    learning_id :: binary(),
    agent_id    :: binary(),
    reason      :: binary() | undefined,
    disputed_at :: integer()
}).

-export_type([learning_disputed_v1/0]).
-opaque learning_disputed_v1() :: #learning_disputed_v1{}.

-spec new(binary(), binary(), binary() | undefined) -> learning_disputed_v1().
new(LearningId, AgentId, Reason) ->
    #learning_disputed_v1{
        learning_id = LearningId,
        agent_id = AgentId,
        reason = Reason,
        disputed_at = erlang:system_time(millisecond)
    }.

-spec to_map(learning_disputed_v1()) -> map().
to_map(#learning_disputed_v1{} = E) ->
    #{
        event_type => <<"learning_disputed_v1">>,
        learning_id => E#learning_disputed_v1.learning_id,
        agent_id => E#learning_disputed_v1.agent_id,
        reason => E#learning_disputed_v1.reason,
        disputed_at => E#learning_disputed_v1.disputed_at
    }.

-spec from_map(map()) -> {ok, learning_disputed_v1()} | {error, term()}.
from_map(#{learning_id := LId, agent_id := AId} = Map) ->
    {ok, #learning_disputed_v1{
        learning_id = LId,
        agent_id = AId,
        reason = maps:get(reason, Map, undefined),
        disputed_at = maps:get(disputed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_learning_id(#learning_disputed_v1{learning_id = V}) -> V.
get_agent_id(#learning_disputed_v1{agent_id = V}) -> V.
get_reason(#learning_disputed_v1{reason = V}) -> V.
get_disputed_at(#learning_disputed_v1{disputed_at = V}) -> V.
