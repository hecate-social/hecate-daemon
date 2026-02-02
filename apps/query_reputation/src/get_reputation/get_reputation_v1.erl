-module(get_reputation_v1).

-export([new/1, to_map/1, from_map/1]).

-record(get_reputation_v1, {
    agent_identity :: binary()
}).

-opaque get_reputation_v1() :: #get_reputation_v1{}.
-export_type([get_reputation_v1/0]).

-spec new(binary()) -> get_reputation_v1().
new(AgentIdentity) ->
    #get_reputation_v1{agent_identity = AgentIdentity}.

-spec to_map(get_reputation_v1()) -> map().
to_map(#get_reputation_v1{agent_identity = Identity}) ->
    #{agent_identity => Identity}.

-spec from_map(map()) -> {ok, get_reputation_v1()} | {error, term()}.
from_map(#{agent_identity := Identity}) ->
    {ok, #get_reputation_v1{agent_identity = Identity}};
from_map(_) ->
    {error, invalid_get_reputation_query}.
