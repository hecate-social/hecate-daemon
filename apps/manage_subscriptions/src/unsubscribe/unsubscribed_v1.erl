%%% @doc unsubscribed_v1 event
%%% Emitted when an agent successfully unsubscribes from a topic.
-module(unsubscribed_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_agent_identity/1, get_topic/1, get_unsubscribed_at/1]).

-record(unsubscribed_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    unsubscribed_at :: integer()
}).

-opaque unsubscribed_v1() :: #unsubscribed_v1{}.
-export_type([unsubscribed_v1/0]).

%% @doc Create a new unsubscribed event.
-spec new(binary(), binary(), integer()) -> unsubscribed_v1().
new(AgentIdentity, Topic, UnsubscribedAt) ->
    #unsubscribed_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt
    }.

%% @doc Convert event to map.
-spec to_map(unsubscribed_v1()) -> map().
to_map(#unsubscribed_v1{
    agent_identity = AgentIdentity,
    topic = Topic,
    unsubscribed_at = UnsubscribedAt
}) ->
    #{
        event_type => <<"unsubscribed_v1">>,
        agent_identity => AgentIdentity,
        topic => Topic,
        unsubscribed_at => UnsubscribedAt
    }.

%% @doc Create event from map.
-spec from_map(map()) -> {ok, unsubscribed_v1()} | {error, term()}.
from_map(#{
    agent_identity := AgentIdentity,
    topic := Topic,
    unsubscribed_at := UnsubscribedAt
}) ->
    {ok, #unsubscribed_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        unsubscribed_at = UnsubscribedAt
    }};
from_map(_) ->
    {error, invalid_unsubscribed_event}.

%% Accessor functions
get_agent_identity(#unsubscribed_v1{agent_identity = A}) -> A.
get_topic(#unsubscribed_v1{topic = T}) -> T.
get_unsubscribed_at(#unsubscribed_v1{unsubscribed_at = U}) -> U.
