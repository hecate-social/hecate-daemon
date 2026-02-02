%%% @doc Command: Record that someone unfollowed one of my identities
%%% Triggered by mesh listener when social.unfollowed fact targets MY_IDENTITIES
-module(record_unfollower_v1).
-export([new/3, to_map/1, from_map/1]).

-record(record_unfollower_v1, {
    unfollower_identity :: binary(),
    my_identity :: binary(),
    unfollowed_at :: integer()
}).

-opaque record_unfollower_v1() :: #record_unfollower_v1{}.
-export_type([record_unfollower_v1/0]).

-spec new(binary(), binary(), integer()) -> record_unfollower_v1().
new(UnfollowerIdentity, MyIdentity, UnfollowedAt) ->
    #record_unfollower_v1{
        unfollower_identity = UnfollowerIdentity,
        my_identity = MyIdentity,
        unfollowed_at = UnfollowedAt
    }.

-spec to_map(record_unfollower_v1()) -> map().
to_map(#record_unfollower_v1{
    unfollower_identity = Unfollower,
    my_identity = MyIdentity,
    unfollowed_at = UnfollowedAt
}) ->
    #{
        unfollower_identity => Unfollower,
        my_identity => MyIdentity,
        unfollowed_at => UnfollowedAt
    }.

-spec from_map(map()) -> {ok, record_unfollower_v1()} | {error, term()}.
from_map(#{
    unfollower_identity := Unfollower,
    my_identity := MyIdentity,
    unfollowed_at := UnfollowedAt
}) ->
    {ok, #record_unfollower_v1{
        unfollower_identity = Unfollower,
        my_identity = MyIdentity,
        unfollowed_at = UnfollowedAt
    }};
from_map(_) ->
    {error, invalid_record_unfollower_command}.
