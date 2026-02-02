%%% @doc Event: An unsubscriber was recorded
-module(unsubscriber_recorded_v1).
-export([new/5, to_map/1, from_map/1]).

-record(unsubscriber_recorded_v1, {
    subscriber_identity :: binary(),
    my_identity :: binary(),
    topic :: binary(),
    unsubscribed_at :: integer(),
    recorded_at :: integer()
}).

-opaque unsubscriber_recorded_v1() :: #unsubscriber_recorded_v1{}.
-export_type([unsubscriber_recorded_v1/0]).

-spec new(binary(), binary(), binary(), integer(), integer()) -> unsubscriber_recorded_v1().
new(SubscriberIdentity, MyIdentity, Topic, UnsubscribedAt, RecordedAt) ->
    #unsubscriber_recorded_v1{
        subscriber_identity = SubscriberIdentity,
        my_identity = MyIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(unsubscriber_recorded_v1()) -> map().
to_map(#unsubscriber_recorded_v1{
    subscriber_identity = Subscriber,
    my_identity = MyIdentity,
    topic = Topic,
    unsubscribed_at = UnsubscribedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"unsubscriber_recorded_v1">>,
        subscriber_identity => Subscriber,
        my_identity => MyIdentity,
        topic => Topic,
        unsubscribed_at => UnsubscribedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, unsubscriber_recorded_v1()} | {error, term()}.
from_map(#{
    subscriber_identity := Subscriber,
    my_identity := MyIdentity,
    topic := Topic,
    unsubscribed_at := UnsubscribedAt,
    recorded_at := RecordedAt
}) ->
    {ok, #unsubscriber_recorded_v1{
        subscriber_identity = Subscriber,
        my_identity = MyIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_unsubscriber_recorded_event}.
