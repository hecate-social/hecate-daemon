%%% @doc subscribed_v1 event
%%% Emitted when an agent successfully subscribes to a topic.
-module(subscribed_v1).

-export([new/4, to_map/1, from_map/1]).
-export([get_agent_identity/1, get_topic/1, get_filter/1, get_subscribed_at/1]).

-record(subscribed_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    filter :: map() | undefined,
    subscribed_at :: integer()
}).

-opaque subscribed_v1() :: #subscribed_v1{}.
-export_type([subscribed_v1/0]).

%% @doc Create a new subscribed event.
-spec new(binary(), binary(), map() | undefined, integer()) -> subscribed_v1().
new(AgentIdentity, Topic, Filter, SubscribedAt) ->
    #subscribed_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt
    }.

%% @doc Convert event to map.
-spec to_map(subscribed_v1()) -> map().
to_map(#subscribed_v1{
    agent_identity = AgentIdentity,
    topic = Topic,
    filter = Filter,
    subscribed_at = SubscribedAt
}) ->
    #{
        event_type => <<"subscribed_v1">>,
        agent_identity => AgentIdentity,
        topic => Topic,
        filter => Filter,
        subscribed_at => SubscribedAt
    }.

%% @doc Create event from map.
-spec from_map(map()) -> {ok, subscribed_v1()} | {error, term()}.
from_map(#{
    agent_identity := AgentIdentity,
    topic := Topic,
    subscribed_at := SubscribedAt
} = Map) ->
    Filter = maps:get(filter, Map, undefined),
    {ok, #subscribed_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt
    }};
from_map(_) ->
    {error, invalid_subscribed_event}.

%% Accessor functions
get_agent_identity(#subscribed_v1{agent_identity = A}) -> A.
get_topic(#subscribed_v1{topic = T}) -> T.
get_filter(#subscribed_v1{filter = F}) -> F.
get_subscribed_at(#subscribed_v1{subscribed_at = S}) -> S.
