%%% @doc mentor_unsubscribed_v1 event
%%% Emitted when an agent unsubscribes from a mentor.
-module(mentor_unsubscribed_v1).

-export([new/2, to_map/1, from_map/1]).
-export([get_subscriber_id/1, get_mentor_id/1, get_unsubscribed_at/1]).

-record(mentor_unsubscribed_v1, {
    subscriber_id   :: binary(),
    mentor_id       :: binary(),
    unsubscribed_at :: integer()
}).

-export_type([mentor_unsubscribed_v1/0]).
-opaque mentor_unsubscribed_v1() :: #mentor_unsubscribed_v1{}.

-spec new(binary(), binary()) -> mentor_unsubscribed_v1().
new(SubscriberId, MentorId) ->
    #mentor_unsubscribed_v1{
        subscriber_id = SubscriberId,
        mentor_id = MentorId,
        unsubscribed_at = erlang:system_time(millisecond)
    }.

-spec to_map(mentor_unsubscribed_v1()) -> map().
to_map(#mentor_unsubscribed_v1{} = E) ->
    #{
        event_type => <<"mentor_unsubscribed_v1">>,
        subscriber_id => E#mentor_unsubscribed_v1.subscriber_id,
        mentor_id => E#mentor_unsubscribed_v1.mentor_id,
        unsubscribed_at => E#mentor_unsubscribed_v1.unsubscribed_at
    }.

-spec from_map(map()) -> {ok, mentor_unsubscribed_v1()} | {error, term()}.
from_map(#{subscriber_id := SId, mentor_id := MId} = Map) ->
    {ok, #mentor_unsubscribed_v1{
        subscriber_id = SId,
        mentor_id = MId,
        unsubscribed_at = maps:get(unsubscribed_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_subscriber_id(#mentor_unsubscribed_v1{subscriber_id = V}) -> V.
get_mentor_id(#mentor_unsubscribed_v1{mentor_id = V}) -> V.
get_unsubscribed_at(#mentor_unsubscribed_v1{unsubscribed_at = V}) -> V.
