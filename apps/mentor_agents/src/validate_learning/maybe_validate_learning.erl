%%% @doc maybe_validate_learning handler
%%% Business logic for validating learnings.
-module(maybe_validate_learning).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


-spec handle(validate_learning_v1:validate_learning_v1()) ->
    {ok, [learning_validated_v1:learning_validated_v1()]} | {error, term()}.
handle(Cmd) ->
    LearningId = validate_learning_v1:get_learning_id(Cmd),
    ValidatorId = validate_learning_v1:get_validator_id(Cmd),
    Event = learning_validated_v1:new(LearningId, ValidatorId),
    {ok, [Event]}.

-spec dispatch(validate_learning_v1:validate_learning_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LearningId = validate_learning_v1:get_learning_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = validate_learning,
        aggregate_type = learning_aggregate,
        aggregate_id = <<"learning-", LearningId/binary>>,
        payload = validate_learning_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => learning_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => mentor_agents_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
