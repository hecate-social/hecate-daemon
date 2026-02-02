%%% @doc Event: An unfollower was recorded (someone unfollowed one of my identities)
-module(unfollower_recorded_v1).
-export([new/4, to_map/1, from_map/1]).

-record(unfollower_recorded_v1, {
    unfollower_identity :: binary(),
    my_identity :: binary(),
    unfollowed_at :: integer(),
    recorded_at :: integer()
}).

-opaque unfollower_recorded_v1() :: #unfollower_recorded_v1{}.
-export_type([unfollower_recorded_v1/0]).

-spec new(binary(), binary(), integer(), integer()) -> unfollower_recorded_v1().
new(UnfollowerIdentity, MyIdentity, UnfollowedAt, RecordedAt) ->
    #unfollower_recorded_v1{
        unfollower_identity = UnfollowerIdentity,
        my_identity = MyIdentity,
        unfollowed_at = UnfollowedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(unfollower_recorded_v1()) -> map().
to_map(#unfollower_recorded_v1{
    unfollower_identity = Unfollower,
    my_identity = MyIdentity,
    unfollowed_at = UnfollowedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"unfollower_recorded_v1">>,
        unfollower_identity => Unfollower,
        my_identity => MyIdentity,
        unfollowed_at => UnfollowedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, unfollower_recorded_v1()} | {error, term()}.
from_map(#{
    unfollower_identity := Unfollower,
    my_identity := MyIdentity,
    unfollowed_at := UnfollowedAt,
    recorded_at := RecordedAt
}) ->
    {ok, #unfollower_recorded_v1{
        unfollower_identity = Unfollower,
        my_identity = MyIdentity,
        unfollowed_at = UnfollowedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_unfollower_recorded_event}.
