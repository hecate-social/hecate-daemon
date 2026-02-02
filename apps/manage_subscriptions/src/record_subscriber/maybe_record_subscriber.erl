%%% @doc Handler for record_subscriber command
-module(maybe_record_subscriber).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{
        subscriber_identity := Subscriber,
        my_identity := MyIdentity,
        topic := Topic,
        filter := Filter,
        subscribed_at := SubscribedAt
    } = record_subscriber_v1:to_map(Command),

    %% Validate: subscriber can't be me
    case Subscriber =/= MyIdentity of
        true ->
            RecordedAt = erlang:system_time(millisecond),
            Event = subscriber_recorded_v1:new(Subscriber, MyIdentity, Topic, Filter, SubscribedAt, RecordedAt),
            {ok, [subscriber_recorded_v1:to_map(Event)]};
        false ->
            {error, cannot_record_self_subscription}
    end.

-spec dispatch(record_subscriber_v1:record_subscriber_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    #{my_identity := MyIdentity} = record_subscriber_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = record_subscriber_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(MyIdentity, Timestamp),
        command_type = record_subscriber,
        aggregate_type = my_subscribers_aggregate,
        aggregate_id = MyIdentity,
        payload = CmdMap#{command_type => record_subscriber},
        metadata = #{timestamp => Timestamp, source => mesh_fact},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_subscriptions_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AggId, Ts) ->
    Hash = crypto:hash(sha256, <<AggId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-record_subscriber-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
