-module(list_rpc_calls_v1).

-export([new/3, to_map/1, from_map/1]).

-record(list_rpc_calls_v1, {
    agent_identity :: binary(),
    limit :: non_neg_integer(),
    success_filter :: boolean() | undefined
}).

-opaque list_rpc_calls_v1() :: #list_rpc_calls_v1{}.
-export_type([list_rpc_calls_v1/0]).

-spec new(binary(), non_neg_integer(), boolean() | undefined) -> list_rpc_calls_v1().
new(AgentIdentity, Limit, SuccessFilter) ->
    #list_rpc_calls_v1{
        agent_identity = AgentIdentity,
        limit = Limit,
        success_filter = SuccessFilter
    }.

-spec to_map(list_rpc_calls_v1()) -> map().
to_map(#list_rpc_calls_v1{
    agent_identity = Identity,
    limit = Limit,
    success_filter = Filter
}) ->
    #{
        agent_identity => Identity,
        limit => Limit,
        success_filter => Filter
    }.

-spec from_map(map()) -> {ok, list_rpc_calls_v1()} | {error, term()}.
from_map(#{agent_identity := Identity} = Map) ->
    Limit = maps:get(limit, Map, 50),
    Filter = maps:get(success_filter, Map, undefined),

    {ok, #list_rpc_calls_v1{
        agent_identity = Identity,
        limit = Limit,
        success_filter = Filter
    }};
from_map(_) ->
    {error, invalid_list_rpc_calls_query}.
