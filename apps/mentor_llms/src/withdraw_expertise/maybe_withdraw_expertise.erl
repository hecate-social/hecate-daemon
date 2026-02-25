%%% @doc maybe_withdraw_expertise handler
%%% Business logic for withdrawing expertise.
-module(maybe_withdraw_expertise).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


-spec handle(withdraw_expertise_v1:withdraw_expertise_v1()) ->
    {ok, [expertise_withdrawn_v1:expertise_withdrawn_v1()]} | {error, term()}.
handle(Cmd) ->
    AgentId = withdraw_expertise_v1:get_agent_id(Cmd),
    Event = expertise_withdrawn_v1:new(AgentId),
    {ok, [Event]}.

-spec dispatch(withdraw_expertise_v1:withdraw_expertise_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    AgentId = withdraw_expertise_v1:get_agent_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = withdraw_expertise,
        aggregate_type = mentor_profile_aggregate,
        aggregate_id = <<"mentor-", AgentId/binary>>,
        payload = withdraw_expertise_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => mentor_profile_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => mentorships_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
