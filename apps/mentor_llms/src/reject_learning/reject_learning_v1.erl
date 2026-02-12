%%% @doc reject_learning_v1 command
%%% Rejects a submitted learning.
-module(reject_learning_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_learning_id/1, get_validator_id/1, get_reason/1]).

-record(reject_learning_v1, {
    learning_id  :: binary(),
    validator_id :: binary(),
    reason       :: binary() | undefined
}).

-export_type([reject_learning_v1/0]).
-opaque reject_learning_v1() :: #reject_learning_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, reject_learning_v1()} | {error, term()}.
new(#{learning_id := LId} = Params) ->
    ValidatorId = case maps:find(validator_id, Params) of
        {ok, VId} -> VId;
        error -> hecate_identity:agent_id()
    end,
    Cmd = #reject_learning_v1{
        learning_id = LId,
        validator_id = ValidatorId,
        reason = maps:get(reason, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(reject_learning_v1()) -> {ok, reject_learning_v1()} | {error, term()}.
validate(#reject_learning_v1{learning_id = LId}) when not is_binary(LId) ->
    {error, invalid_learning_id};
validate(#reject_learning_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(reject_learning_v1()) -> map().
to_map(#reject_learning_v1{} = Cmd) ->
    #{
        command_type => <<"reject_learning">>,
        learning_id => Cmd#reject_learning_v1.learning_id,
        validator_id => Cmd#reject_learning_v1.validator_id,
        reason => Cmd#reject_learning_v1.reason
    }.

-spec from_map(map()) -> {ok, reject_learning_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

get_learning_id(#reject_learning_v1{learning_id = V}) -> V.
get_validator_id(#reject_learning_v1{validator_id = V}) -> V.
get_reason(#reject_learning_v1{reason = V}) -> V.
