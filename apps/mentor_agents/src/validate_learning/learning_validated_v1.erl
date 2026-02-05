%%% @doc learning_validated_v1 event
%%% Emitted when a learning is validated by a mentor.
-module(learning_validated_v1).

-export([new/2, to_map/1, from_map/1]).
-export([get_learning_id/1, get_validator_id/1, get_validated_at/1]).

-record(learning_validated_v1, {
    learning_id  :: binary(),
    validator_id :: binary(),
    validated_at :: integer()
}).

-export_type([learning_validated_v1/0]).
-opaque learning_validated_v1() :: #learning_validated_v1{}.

-spec new(binary(), binary()) -> learning_validated_v1().
new(LearningId, ValidatorId) ->
    #learning_validated_v1{
        learning_id = LearningId,
        validator_id = ValidatorId,
        validated_at = erlang:system_time(millisecond)
    }.

-spec to_map(learning_validated_v1()) -> map().
to_map(#learning_validated_v1{} = E) ->
    #{
        event_type => <<"learning_validated_v1">>,
        learning_id => E#learning_validated_v1.learning_id,
        validator_id => E#learning_validated_v1.validator_id,
        validated_at => E#learning_validated_v1.validated_at
    }.

-spec from_map(map()) -> {ok, learning_validated_v1()} | {error, term()}.
from_map(#{learning_id := LId, validator_id := VId} = Map) ->
    {ok, #learning_validated_v1{
        learning_id = LId,
        validator_id = VId,
        validated_at = maps:get(validated_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_learning_id(#learning_validated_v1{learning_id = V}) -> V.
get_validator_id(#learning_validated_v1{validator_id = V}) -> V.
get_validated_at(#learning_validated_v1{validated_at = V}) -> V.
