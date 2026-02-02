%%% @doc Event: A follower was recorded (someone followed one of my identities)
-module(follower_recorded_v1).
-export([new/4, to_map/1, from_map/1]).

-record(follower_recorded_v1, {
    follower_identity :: binary(),   %% Who followed me
    my_identity :: binary(),         %% Which of my identities was followed
    followed_at :: integer(),        %% When they followed (from mesh fact)
    recorded_at :: integer()         %% When we recorded this locally
}).

-opaque follower_recorded_v1() :: #follower_recorded_v1{}.
-export_type([follower_recorded_v1/0]).

-spec new(binary(), binary(), integer(), integer()) -> follower_recorded_v1().
new(FollowerIdentity, MyIdentity, FollowedAt, RecordedAt) ->
    #follower_recorded_v1{
        follower_identity = FollowerIdentity,
        my_identity = MyIdentity,
        followed_at = FollowedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(follower_recorded_v1()) -> map().
to_map(#follower_recorded_v1{
    follower_identity = Follower,
    my_identity = MyIdentity,
    followed_at = FollowedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"follower_recorded_v1">>,
        follower_identity => Follower,
        my_identity => MyIdentity,
        followed_at => FollowedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, follower_recorded_v1()} | {error, term()}.
from_map(#{
    follower_identity := Follower,
    my_identity := MyIdentity,
    followed_at := FollowedAt,
    recorded_at := RecordedAt
}) ->
    {ok, #follower_recorded_v1{
        follower_identity = Follower,
        my_identity = MyIdentity,
        followed_at = FollowedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_follower_recorded_event}.
