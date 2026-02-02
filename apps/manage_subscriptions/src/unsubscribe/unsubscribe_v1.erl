%%% @doc unsubscribe_v1 command
%%% Command to unsubscribe an agent from a topic.
-module(unsubscribe_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_agent_identity/1, get_topic/1, get_unsubscribed_at/1]).

-record(unsubscribe_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    unsubscribed_at :: integer()
}).

-opaque unsubscribe_v1() :: #unsubscribe_v1{}.
-export_type([unsubscribe_v1/0]).

%% @doc Create a new unsubscribe command.
-spec new(binary(), binary(), integer()) -> unsubscribe_v1().
new(AgentIdentity, Topic, UnsubscribedAt) ->
    #unsubscribe_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt
    }.

%% @doc Convert command to map.
-spec to_map(unsubscribe_v1()) -> map().
to_map(#unsubscribe_v1{
    agent_identity = AgentIdentity,
    topic = Topic,
    unsubscribed_at = UnsubscribedAt
}) ->
    #{
        agent_identity => AgentIdentity,
        topic => Topic,
        unsubscribed_at => UnsubscribedAt
    }.

%% @doc Create command from map.
-spec from_map(map()) -> {ok, unsubscribe_v1()} | {error, term()}.
from_map(#{
    agent_identity := AgentIdentity,
    topic := Topic,
    unsubscribed_at := UnsubscribedAt
}) ->
    {ok, #unsubscribe_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt
    }};
from_map(_) ->
    {error, invalid_unsubscribe_command}.

%% Accessor functions
get_agent_identity(#unsubscribe_v1{agent_identity = A}) -> A.
get_topic(#unsubscribe_v1{topic = T}) -> T.
get_unsubscribed_at(#unsubscribe_v1{unsubscribed_at = U}) -> U.
