%%% @doc Event: A subscriber was recorded (someone subscribed to my service)
-module(subscriber_recorded_v1).
-export([new/6, to_map/1, from_map/1]).

-record(subscriber_recorded_v1, {
    subscriber_identity :: binary(),
    my_identity :: binary(),
    topic :: binary(),
    filter :: binary() | undefined,
    subscribed_at :: integer(),
    recorded_at :: integer()
}).

-opaque subscriber_recorded_v1() :: #subscriber_recorded_v1{}.
-export_type([subscriber_recorded_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, integer(), integer()) -> subscriber_recorded_v1().
new(SubscriberIdentity, MyIdentity, Topic, Filter, SubscribedAt, RecordedAt) ->
    #subscriber_recorded_v1{
        subscriber_identity = SubscriberIdentity,
        my_identity = MyIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(subscriber_recorded_v1()) -> map().
to_map(#subscriber_recorded_v1{
    subscriber_identity = Subscriber,
    my_identity = MyIdentity,
    topic = Topic,
    filter = Filter,
    subscribed_at = SubscribedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"subscriber_recorded_v1">>,
        subscriber_identity => Subscriber,
        my_identity => MyIdentity,
        topic => Topic,
        filter => Filter,
        subscribed_at => SubscribedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, subscriber_recorded_v1()} | {error, term()}.
from_map(#{
    subscriber_identity := Subscriber,
    my_identity := MyIdentity,
    topic := Topic,
    subscribed_at := SubscribedAt,
    recorded_at := RecordedAt
} = Map) ->
    Filter = maps:get(filter, Map, undefined),
    {ok, #subscriber_recorded_v1{
        subscriber_identity = Subscriber,
        my_identity = MyIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_subscriber_recorded_event}.
