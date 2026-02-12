%%% @doc maybe_endorse_learning handler
%%% Business logic for endorsing learnings.
-module(maybe_endorse_learning).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


-spec handle(endorse_learning_v1:endorse_learning_v1()) ->
    {ok, [learning_endorsed_v1:learning_endorsed_v1()]} | {error, term()}.
handle(Cmd) ->
    LearningId = endorse_learning_v1:get_learning_id(Cmd),
    AgentId = endorse_learning_v1:get_agent_id(Cmd),
    Event = learning_endorsed_v1:new(LearningId, AgentId),
    {ok, [Event]}.

-spec dispatch(endorse_learning_v1:endorse_learning_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LearningId = endorse_learning_v1:get_learning_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = endorse_learning,
        aggregate_type = learning_aggregate,
        aggregate_id = <<"learning-", LearningId/binary>>,
        payload = endorse_learning_v1:to_map(Cmd),
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
