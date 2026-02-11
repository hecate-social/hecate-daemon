%%% @doc maybe_reject_learning handler
%%% Business logic for rejecting learnings.
-module(maybe_reject_learning).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-spec handle(reject_learning_v1:reject_learning_v1()) ->
    {ok, [learning_rejected_v1:learning_rejected_v1()]} | {error, term()}.
handle(Cmd) ->
    LearningId = reject_learning_v1:get_learning_id(Cmd),
    ValidatorId = reject_learning_v1:get_validator_id(Cmd),
    Reason = reject_learning_v1:get_reason(Cmd),
    Event = learning_rejected_v1:new(LearningId, ValidatorId, Reason),
    {ok, [Event]}.

-spec dispatch(reject_learning_v1:reject_learning_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LearningId = reject_learning_v1:get_learning_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_command_id(LearningId, Timestamp),
        command_type = reject_learning,
        aggregate_type = learning_aggregate,
        aggregate_id = <<"learning-", LearningId/binary>>,
        payload = reject_learning_v1:to_map(Cmd),
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

generate_command_id(LearningId, Timestamp) ->
    Unique = integer_to_binary(erlang:unique_integer([positive])),
    Hash = crypto:hash(sha256, <<LearningId/binary, (integer_to_binary(Timestamp))/binary, "-", Unique/binary>>),
    HashHex = binary:encode_hex(Hash),
    ShortHash = binary:part(HashHex, 0, 16),
    <<"cmd-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>.
