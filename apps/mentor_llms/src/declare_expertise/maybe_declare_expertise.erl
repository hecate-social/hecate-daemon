%%% @doc maybe_declare_expertise handler
%%% Business logic for declaring expertise.
-module(maybe_declare_expertise).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


-spec handle(declare_expertise_v1:declare_expertise_v1()) ->
    {ok, [expertise_declared_v1:expertise_declared_v1()]} | {error, term()}.
handle(Cmd) ->
    AgentId = declare_expertise_v1:get_agent_id(Cmd),
    Domains = declare_expertise_v1:get_domains(Cmd),
    Event = expertise_declared_v1:new(AgentId, Domains),
    {ok, [Event]}.

-spec dispatch(declare_expertise_v1:declare_expertise_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    AgentId = declare_expertise_v1:get_agent_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = declare_expertise,
        aggregate_type = mentor_profile_aggregate,
        aggregate_id = <<"mentor-", AgentId/binary>>,
        payload = declare_expertise_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => mentor_profile_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
