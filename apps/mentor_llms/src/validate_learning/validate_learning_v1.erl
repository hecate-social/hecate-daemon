%%% @doc validate_learning_v1 command
%%% Validates a submitted learning.
-module(validate_learning_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_learning_id/1, get_validator_id/1]).

-record(validate_learning_v1, {
    learning_id  :: binary(),
    validator_id :: binary()
}).

-export_type([validate_learning_v1/0]).
-opaque validate_learning_v1() :: #validate_learning_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, validate_learning_v1()} | {error, term()}.
new(#{learning_id := LId} = Params) ->
    ValidatorId = case maps:find(validator_id, Params) of
        {ok, VId} -> VId;
        error -> hecate_identity:agent_id()
    end,
    Cmd = #validate_learning_v1{
        learning_id = LId,
        validator_id = ValidatorId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(validate_learning_v1()) -> {ok, validate_learning_v1()} | {error, term()}.
validate(#validate_learning_v1{learning_id = LId}) when not is_binary(LId) ->
    {error, invalid_learning_id};
validate(#validate_learning_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(validate_learning_v1()) -> map().
to_map(#validate_learning_v1{} = Cmd) ->
    #{
        command_type => <<"validate_learning">>,
        learning_id => Cmd#validate_learning_v1.learning_id,
        validator_id => Cmd#validate_learning_v1.validator_id
    }.

-spec from_map(map()) -> {ok, validate_learning_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_learning_id(#validate_learning_v1{learning_id = V}) -> V.
get_validator_id(#validate_learning_v1{validator_id = V}) -> V.
