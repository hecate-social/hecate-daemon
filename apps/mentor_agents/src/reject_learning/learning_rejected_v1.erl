%%% @doc learning_rejected_v1 event
%%% Emitted when a learning is rejected.
-module(learning_rejected_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_learning_id/1, get_validator_id/1, get_reason/1, get_rejected_at/1]).

-record(learning_rejected_v1, {
    learning_id  :: binary(),
    validator_id :: binary(),
    reason       :: binary() | undefined,
    rejected_at  :: integer()
}).

-export_type([learning_rejected_v1/0]).
-opaque learning_rejected_v1() :: #learning_rejected_v1{}.

-spec new(binary(), binary(), binary() | undefined) -> learning_rejected_v1().
new(LearningId, ValidatorId, Reason) ->
    #learning_rejected_v1{
        learning_id = LearningId,
        validator_id = ValidatorId,
        reason = Reason,
        rejected_at = erlang:system_time(millisecond)
    }.

-spec to_map(learning_rejected_v1()) -> map().
to_map(#learning_rejected_v1{} = E) ->
    #{
        event_type => <<"learning_rejected_v1">>,
        learning_id => E#learning_rejected_v1.learning_id,
        validator_id => E#learning_rejected_v1.validator_id,
        reason => E#learning_rejected_v1.reason,
        rejected_at => E#learning_rejected_v1.rejected_at
    }.

-spec from_map(map()) -> {ok, learning_rejected_v1()} | {error, term()}.
from_map(#{learning_id := LId, validator_id := VId} = Map) ->
    {ok, #learning_rejected_v1{
        learning_id = LId,
        validator_id = VId,
        reason = maps:get(reason, Map, undefined),
        rejected_at = maps:get(rejected_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_learning_id(#learning_rejected_v1{learning_id = V}) -> V.
get_validator_id(#learning_rejected_v1{validator_id = V}) -> V.
get_reason(#learning_rejected_v1{reason = V}) -> V.
get_rejected_at(#learning_rejected_v1{rejected_at = V}) -> V.
