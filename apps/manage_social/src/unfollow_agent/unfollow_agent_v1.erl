-module(unfollow_agent_v1).
-export([new/2, to_map/1, from_map/1]).

-record(unfollow_agent_v1, {
    follower_identity :: binary(),
    followed_identity :: binary()
}).

-opaque unfollow_agent_v1() :: #unfollow_agent_v1{}.
-export_type([unfollow_agent_v1/0]).

-spec new(binary(), binary()) -> unfollow_agent_v1().
new(FollowerIdentity, FollowedIdentity) ->
    #unfollow_agent_v1{follower_identity = FollowerIdentity, followed_identity = FollowedIdentity}.

-spec to_map(unfollow_agent_v1()) -> map().
to_map(#unfollow_agent_v1{follower_identity = Follower, followed_identity = Followed}) ->
    #{follower_identity => Follower, followed_identity => Followed}.

-spec from_map(map()) -> {ok, unfollow_agent_v1()} | {error, term()}.
from_map(#{follower_identity := Follower, followed_identity := Followed}) ->
    {ok, #unfollow_agent_v1{follower_identity = Follower, followed_identity = Followed}};
from_map(_) ->
    {error, invalid_unfollow_agent_command}.
