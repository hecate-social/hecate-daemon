-module(agent_unfollowed_v1).
-export([new/3, to_map/1, from_map/1]).

-record(agent_unfollowed_v1, {
    follower_identity :: binary(),
    followed_identity :: binary(),
    unfollowed_at :: integer()
}).

-opaque agent_unfollowed_v1() :: #agent_unfollowed_v1{}.
-export_type([agent_unfollowed_v1/0]).

-spec new(binary(), binary(), integer()) -> agent_unfollowed_v1().
new(FollowerIdentity, FollowedIdentity, UnfollowedAt) ->
    #agent_unfollowed_v1{follower_identity = FollowerIdentity, followed_identity = FollowedIdentity, unfollowed_at = UnfollowedAt}.

-spec to_map(agent_unfollowed_v1()) -> map().
to_map(#agent_unfollowed_v1{follower_identity = Follower, followed_identity = Followed, unfollowed_at = UnfollowedAt}) ->
    #{
        event_type => <<"agent_unfollowed_v1">>,
        follower_identity => Follower,
        followed_identity => Followed,
        unfollowed_at => UnfollowedAt
    }.

-spec from_map(map()) -> {ok, agent_unfollowed_v1()} | {error, term()}.
from_map(#{follower_identity := Follower, followed_identity := Followed, unfollowed_at := UnfollowedAt}) ->
    {ok, #agent_unfollowed_v1{follower_identity = Follower, followed_identity = Followed, unfollowed_at = UnfollowedAt}};
from_map(_) ->
    {error, invalid_agent_unfollowed_event}.
