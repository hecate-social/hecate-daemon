-module(follow_agent_v1).
-export([new/2, to_map/1, from_map/1]).

-record(follow_agent_v1, {
    follower_identity :: binary(),
    followed_identity :: binary()
}).

-opaque follow_agent_v1() :: #follow_agent_v1{}.
-export_type([follow_agent_v1/0]).

-spec new(binary(), binary()) -> follow_agent_v1().
new(FollowerIdentity, FollowedIdentity) ->
    #follow_agent_v1{follower_identity = FollowerIdentity, followed_identity = FollowedIdentity}.

-spec to_map(follow_agent_v1()) -> map().
to_map(#follow_agent_v1{follower_identity = Follower, followed_identity = Followed}) ->
    #{follower_identity => Follower, followed_identity => Followed}.

-spec from_map(map()) -> {ok, follow_agent_v1()} | {error, term()}.
from_map(#{follower_identity := Follower, followed_identity := Followed}) ->
    {ok, #follow_agent_v1{follower_identity = Follower, followed_identity = Followed}};
from_map(_) ->
    {error, invalid_follow_agent_command}.
