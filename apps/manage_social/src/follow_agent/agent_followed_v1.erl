-module(agent_followed_v1).
-export([new/3, to_map/1, from_map/1]).

-record(agent_followed_v1, {
    follower_identity :: binary(),
    followed_identity :: binary(),
    followed_at :: integer()
}).

-opaque agent_followed_v1() :: #agent_followed_v1{}.
-export_type([agent_followed_v1/0]).

-spec new(binary(), binary(), integer()) -> agent_followed_v1().
new(FollowerIdentity, FollowedIdentity, FollowedAt) ->
    #agent_followed_v1{follower_identity = FollowerIdentity, followed_identity = FollowedIdentity, followed_at = FollowedAt}.

-spec to_map(agent_followed_v1()) -> map().
to_map(#agent_followed_v1{follower_identity = Follower, followed_identity = Followed, followed_at = FollowedAt}) ->
    #{
        event_type => <<"agent_followed_v1">>,
        follower_identity => Follower,
        followed_identity => Followed,
        followed_at => FollowedAt
    }.

-spec from_map(map()) -> {ok, agent_followed_v1()} | {error, term()}.
from_map(#{follower_identity := Follower, followed_identity := Followed, followed_at := FollowedAt}) ->
    {ok, #agent_followed_v1{follower_identity = Follower, followed_identity = Followed, followed_at = FollowedAt}};
from_map(_) ->
    {error, invalid_agent_followed_event}.
