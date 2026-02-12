%%% @doc maybe_subscribe_to_mentor handler
%%% Business logic for subscribing to a mentor.
-module(maybe_subscribe_to_mentor).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


-spec handle(subscribe_to_mentor_v1:subscribe_to_mentor_v1()) ->
    {ok, [mentor_subscribed_v1:mentor_subscribed_v1()]} | {error, term()}.
handle(Cmd) ->
    SubscriberId = subscribe_to_mentor_v1:get_subscriber_id(Cmd),
    MentorId = subscribe_to_mentor_v1:get_mentor_id(Cmd),
    Event = mentor_subscribed_v1:new(SubscriberId, MentorId),
    {ok, [Event]}.

-spec dispatch(subscribe_to_mentor_v1:subscribe_to_mentor_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    SubscriberId = subscribe_to_mentor_v1:get_subscriber_id(Cmd),
    MentorId = subscribe_to_mentor_v1:get_mentor_id(Cmd),
    AggId = <<"mentor-sub-", SubscriberId/binary, "-", MentorId/binary>>,
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = subscribe_to_mentor,
        aggregate_type = mentor_subscription_aggregate,
        aggregate_id = AggId,
        payload = subscribe_to_mentor_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => mentor_subscription_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
