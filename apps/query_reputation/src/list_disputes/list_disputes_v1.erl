-module(list_disputes_v1).

-export([new/2, to_map/1, from_map/1]).

-record(list_disputes_v1, {
    agent_identity :: binary() | undefined,
    status_filter :: binary() | undefined  % pending | resolved
}).

-opaque list_disputes_v1() :: #list_disputes_v1{}.
-export_type([list_disputes_v1/0]).

-spec new(binary() | undefined, binary() | undefined) -> list_disputes_v1().
new(AgentIdentity, StatusFilter) ->
    #list_disputes_v1{
        agent_identity = AgentIdentity,
        status_filter = StatusFilter
    }.

-spec to_map(list_disputes_v1()) -> map().
to_map(#list_disputes_v1{
    agent_identity = Identity,
    status_filter = Filter
}) ->
    #{
        agent_identity => Identity,
        status_filter => Filter
    }.

-spec from_map(map()) -> {ok, list_disputes_v1()}.
from_map(Map) ->
    Identity = maps:get(agent_identity, Map, undefined),
    Filter = maps:get(status_filter, Map, undefined),

    {ok, #list_disputes_v1{
        agent_identity = Identity,
        status_filter = Filter
    }}.
