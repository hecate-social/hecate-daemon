-module(get_disputes_page_v1).

-export([new/2, to_map/1, from_map/1]).

-record(get_disputes_page_v1, {
    agent_identity :: binary() | undefined,
    status_filter :: binary() | undefined  % pending | resolved
}).

-opaque get_disputes_page_v1() :: #get_disputes_page_v1{}.
-export_type([get_disputes_page_v1/0]).

-spec new(binary() | undefined, binary() | undefined) -> get_disputes_page_v1().
new(AgentIdentity, StatusFilter) ->
    #get_disputes_page_v1{
        agent_identity = AgentIdentity,
        status_filter = StatusFilter
    }.

-spec to_map(get_disputes_page_v1()) -> map().
to_map(#get_disputes_page_v1{
    agent_identity = Identity,
    status_filter = Filter
}) ->
    #{
        agent_identity => Identity,
        status_filter => Filter
    }.

-spec from_map(map()) -> {ok, get_disputes_page_v1()}.
from_map(Map) ->
    Identity = maps:get(agent_identity, Map, undefined),
    Filter = maps:get(status_filter, Map, undefined),

    {ok, #get_disputes_page_v1{
        agent_identity = Identity,
        status_filter = Filter
    }}.
