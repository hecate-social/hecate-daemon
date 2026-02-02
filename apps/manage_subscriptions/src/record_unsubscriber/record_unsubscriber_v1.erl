%%% @doc Command: Record that someone unsubscribed from one of my topics/services
-module(record_unsubscriber_v1).
-export([new/4, to_map/1, from_map/1]).

-record(record_unsubscriber_v1, {
    subscriber_identity :: binary(),
    my_identity :: binary(),
    topic :: binary(),
    unsubscribed_at :: integer()
}).

-opaque record_unsubscriber_v1() :: #record_unsubscriber_v1{}.
-export_type([record_unsubscriber_v1/0]).

-spec new(binary(), binary(), binary(), integer()) -> record_unsubscriber_v1().
new(SubscriberIdentity, MyIdentity, Topic, UnsubscribedAt) ->
    #record_unsubscriber_v1{
        subscriber_identity = SubscriberIdentity,
        my_identity = MyIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt
    }.

-spec to_map(record_unsubscriber_v1()) -> map().
to_map(#record_unsubscriber_v1{
    subscriber_identity = Subscriber,
    my_identity = MyIdentity,
    topic = Topic,
    unsubscribed_at = UnsubscribedAt
}) ->
    #{
        subscriber_identity => Subscriber,
        my_identity => MyIdentity,
        topic => Topic,
        unsubscribed_at => UnsubscribedAt
    }.

-spec from_map(map()) -> {ok, record_unsubscriber_v1()} | {error, term()}.
from_map(#{
    subscriber_identity := Subscriber,
    my_identity := MyIdentity,
    topic := Topic,
    unsubscribed_at := UnsubscribedAt
}) ->
    {ok, #record_unsubscriber_v1{
        subscriber_identity = Subscriber,
        my_identity = MyIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt
    }};
from_map(_) ->
    {error, invalid_record_unsubscriber_command}.
