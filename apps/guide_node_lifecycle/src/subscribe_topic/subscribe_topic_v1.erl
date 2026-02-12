%%% @doc Command: subscribe to a mesh topic.
-module(subscribe_topic_v1).
-export([new/4, to_map/1, from_map/1]).

-record(subscribe_topic_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    filter :: map() | undefined,
    subscribed_at :: integer()
}).

new(AgentIdentity, Topic, Filter, SubscribedAt) ->
    #subscribe_topic_v1{agent_identity = AgentIdentity, topic = Topic, filter = Filter, subscribed_at = SubscribedAt}.

to_map(#subscribe_topic_v1{agent_identity = A, topic = T, filter = F, subscribed_at = S}) ->
    #{agent_identity => A, topic => T, filter => F, subscribed_at => S}.

from_map(#{agent_identity := A, topic := T, subscribed_at := S} = Map) ->
    F = maps:get(filter, Map, undefined),
    {ok, #subscribe_topic_v1{agent_identity = A, topic = T, filter = F, subscribed_at = S}};
from_map(_) ->
    {error, invalid_subscribe_topic_command}.
