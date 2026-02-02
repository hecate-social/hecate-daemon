%%% @doc Command: Record that someone followed one of my identities
%%% Triggered by mesh listener when social.followed fact targets MY_IDENTITIES
-module(record_follower_v1).
-export([new/3, to_map/1, from_map/1]).

-record(record_follower_v1, {
    follower_identity :: binary(),   %% Who followed me
    my_identity :: binary(),         %% Which of my identities was followed
    followed_at :: integer()         %% When they followed (from mesh fact)
}).

-opaque record_follower_v1() :: #record_follower_v1{}.
-export_type([record_follower_v1/0]).

-spec new(binary(), binary(), integer()) -> record_follower_v1().
new(FollowerIdentity, MyIdentity, FollowedAt) ->
    #record_follower_v1{
        follower_identity = FollowerIdentity,
        my_identity = MyIdentity,
        followed_at = FollowedAt
    }.

-spec to_map(record_follower_v1()) -> map().
to_map(#record_follower_v1{
    follower_identity = Follower,
    my_identity = MyIdentity,
    followed_at = FollowedAt
}) ->
    #{
        follower_identity => Follower,
        my_identity => MyIdentity,
        followed_at => FollowedAt
    }.

-spec from_map(map()) -> {ok, record_follower_v1()} | {error, term()}.
from_map(#{
    follower_identity := Follower,
    my_identity := MyIdentity,
    followed_at := FollowedAt
}) ->
    {ok, #record_follower_v1{
        follower_identity = Follower,
        my_identity = MyIdentity,
        followed_at = FollowedAt
    }};
from_map(_) ->
    {error, invalid_record_follower_command}.
