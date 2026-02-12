-module(topic_unsubscribed_v1).
-export([new/3, to_map/1, from_map/1]).

-record(topic_unsubscribed_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    unsubscribed_at :: integer()
}).

new(AgentIdentity, Topic, UnsubscribedAt) ->
    #topic_unsubscribed_v1{agent_identity = AgentIdentity, topic = Topic, unsubscribed_at = UnsubscribedAt}.

to_map(#topic_unsubscribed_v1{agent_identity = A, topic = T, unsubscribed_at = U}) ->
    #{event_type => <<"topic_unsubscribed_v1">>, agent_identity => A, topic => T, unsubscribed_at => U}.

from_map(#{agent_identity := A, topic := T, unsubscribed_at := U}) ->
    {ok, #topic_unsubscribed_v1{agent_identity = A, topic = T, unsubscribed_at = U}};
from_map(_) ->
    {error, invalid_topic_unsubscribed_event}.
