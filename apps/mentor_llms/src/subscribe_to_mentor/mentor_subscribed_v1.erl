%%% @doc mentor_subscribed_v1 event
%%% Emitted when an agent subscribes to a mentor.
-module(mentor_subscribed_v1).

-export([new/2, to_map/1, from_map/1]).
-export([get_subscriber_id/1, get_mentor_id/1, get_subscribed_at/1]).

-record(mentor_subscribed_v1, {
    subscriber_id :: binary(),
    mentor_id     :: binary(),
    subscribed_at :: integer()
}).

-export_type([mentor_subscribed_v1/0]).
-opaque mentor_subscribed_v1() :: #mentor_subscribed_v1{}.

-spec new(binary(), binary()) -> mentor_subscribed_v1().
new(SubscriberId, MentorId) ->
    #mentor_subscribed_v1{
        subscriber_id = SubscriberId,
        mentor_id = MentorId,
        subscribed_at = erlang:system_time(millisecond)
    }.

-spec to_map(mentor_subscribed_v1()) -> map().
to_map(#mentor_subscribed_v1{} = E) ->
    #{
        event_type => <<"mentor_subscribed_v1">>,
        subscriber_id => E#mentor_subscribed_v1.subscriber_id,
        mentor_id => E#mentor_subscribed_v1.mentor_id,
        subscribed_at => E#mentor_subscribed_v1.subscribed_at
    }.

-spec from_map(map()) -> {ok, mentor_subscribed_v1()} | {error, term()}.
from_map(#{subscriber_id := SId, mentor_id := MId} = Map) ->
    {ok, #mentor_subscribed_v1{
        subscriber_id = SId,
        mentor_id = MId,
        subscribed_at = maps:get(subscribed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_subscriber_id(#mentor_subscribed_v1{subscriber_id = V}) -> V.
get_mentor_id(#mentor_subscribed_v1{mentor_id = V}) -> V.
get_subscribed_at(#mentor_subscribed_v1{subscribed_at = V}) -> V.
