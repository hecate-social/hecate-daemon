%%% @doc Command: Record that someone subscribed to one of my topics/services
%%% Triggered by mesh listener when subscription.subscribed fact targets MY_IDENTITIES
-module(record_subscriber_v1).
-export([new/5, to_map/1, from_map/1]).

-record(record_subscriber_v1, {
    subscriber_identity :: binary(),
    my_identity :: binary(),
    topic :: binary(),
    filter :: binary() | undefined,
    subscribed_at :: integer()
}).

-opaque record_subscriber_v1() :: #record_subscriber_v1{}.
-export_type([record_subscriber_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, integer()) -> record_subscriber_v1().
new(SubscriberIdentity, MyIdentity, Topic, Filter, SubscribedAt) ->
    #record_subscriber_v1{
        subscriber_identity = SubscriberIdentity,
        my_identity = MyIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt
    }.

-spec to_map(record_subscriber_v1()) -> map().
to_map(#record_subscriber_v1{
    subscriber_identity = Subscriber,
    my_identity = MyIdentity,
    topic = Topic,
    filter = Filter,
    subscribed_at = SubscribedAt
}) ->
    #{
        subscriber_identity => Subscriber,
        my_identity => MyIdentity,
        topic => Topic,
        filter => Filter,
        subscribed_at => SubscribedAt
    }.

-spec from_map(map()) -> {ok, record_subscriber_v1()} | {error, term()}.
from_map(#{
    subscriber_identity := Subscriber,
    my_identity := MyIdentity,
    topic := Topic,
    subscribed_at := SubscribedAt
} = Map) ->
    Filter = maps:get(filter, Map, undefined),
    {ok, #record_subscriber_v1{
        subscriber_identity = Subscriber,
        my_identity = MyIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt
    }};
from_map(_) ->
    {error, invalid_record_subscriber_command}.
