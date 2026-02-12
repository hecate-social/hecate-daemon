-module(unsubscribe_topic_v1).
-export([new/3, to_map/1, from_map/1]).

-record(unsubscribe_topic_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    unsubscribed_at :: integer()
}).

new(AgentIdentity, Topic, UnsubscribedAt) ->
    #unsubscribe_topic_v1{agent_identity = AgentIdentity, topic = Topic, unsubscribed_at = UnsubscribedAt}.

to_map(#unsubscribe_topic_v1{agent_identity = A, topic = T, unsubscribed_at = U}) ->
    #{agent_identity => A, topic => T, unsubscribed_at => U}.

from_map(#{agent_identity := A, topic := T, unsubscribed_at := U}) ->
    {ok, #unsubscribe_topic_v1{agent_identity = A, topic = T, unsubscribed_at = U}};
from_map(_) ->
    {error, invalid_unsubscribe_topic_command}.
