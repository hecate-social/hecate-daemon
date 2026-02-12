%%% @doc maybe_resolve_learning_dispute handler
%%% Business logic for resolving disputes.
-module(maybe_resolve_learning_dispute).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


-spec handle(resolve_learning_dispute_v1:resolve_learning_dispute_v1()) ->
    {ok, [learning_dispute_resolved_v1:learning_dispute_resolved_v1()]} | {error, term()}.
handle(Cmd) ->
    LearningId = resolve_learning_dispute_v1:get_learning_id(Cmd),
    ResolverId = resolve_learning_dispute_v1:get_resolver_id(Cmd),
    Resolution = resolve_learning_dispute_v1:get_resolution(Cmd),
    Event = learning_dispute_resolved_v1:new(LearningId, ResolverId, Resolution),
    {ok, [Event]}.

-spec dispatch(resolve_learning_dispute_v1:resolve_learning_dispute_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LearningId = resolve_learning_dispute_v1:get_learning_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = resolve_learning_dispute,
        aggregate_type = learning_aggregate,
        aggregate_id = <<"learning-", LearningId/binary>>,
        payload = resolve_learning_dispute_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => learning_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
