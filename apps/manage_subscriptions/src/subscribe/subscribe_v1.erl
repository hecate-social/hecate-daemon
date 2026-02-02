%%% @doc subscribe_v1 command
%%% Command to subscribe an agent to a topic.
-module(subscribe_v1).

-export([new/4, to_map/1, from_map/1]).
-export([get_agent_identity/1, get_topic/1, get_filter/1, get_subscribed_at/1]).

-record(subscribe_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    filter :: map() | undefined,
    subscribed_at :: integer()
}).

-opaque subscribe_v1() :: #subscribe_v1{}.
-export_type([subscribe_v1/0]).

%% @doc Create a new subscribe command.
-spec new(binary(), binary(), map() | undefined, integer()) -> subscribe_v1().
new(AgentIdentity, Topic, Filter, SubscribedAt) ->
    #subscribe_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt
    }.

%% @doc Convert command to map.
-spec to_map(subscribe_v1()) -> map().
to_map(#subscribe_v1{
    agent_identity = AgentIdentity,
    topic = Topic,
    filter = Filter,
    subscribed_at = SubscribedAt
}) ->
    #{
        agent_identity => AgentIdentity,
        topic => Topic,
        filter => Filter,
        subscribed_at => SubscribedAt
    }.

%% @doc Create command from map.
-spec from_map(map()) -> {ok, subscribe_v1()} | {error, term()}.
from_map(#{
    agent_identity := AgentIdentity,
    topic := Topic,
    subscribed_at := SubscribedAt
} = Map) ->
    Filter = maps:get(filter, Map, undefined),
    {ok, #subscribe_v1{
        agent_identity = AgentIdentity,
        topic = Topic,
        filter = Filter,
        subscribed_at = SubscribedAt
    }};
from_map(_) ->
    {error, invalid_subscribe_command}.

%% Accessor functions
get_agent_identity(#subscribe_v1{agent_identity = A}) -> A.
get_topic(#subscribe_v1{topic = T}) -> T.
get_filter(#subscribe_v1{filter = F}) -> F.
get_subscribed_at(#subscribe_v1{subscribed_at = S}) -> S.
