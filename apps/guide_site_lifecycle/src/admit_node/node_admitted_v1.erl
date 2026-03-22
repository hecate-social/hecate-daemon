%%% @doc node_admitted_v1 event
-module(node_admitted_v1).

-behaviour(evoq_event).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([event_type/0]).

-record(node_admitted_v1, {
    node_name   :: binary(),
    admitted_at :: integer()
}).

-opaque node_admitted_v1() :: #node_admitted_v1{}.
-export_type([node_admitted_v1/0]).

-spec new(binary(), integer()) -> node_admitted_v1().
event_type() -> <<"node_admitted_v1">>.

new(#{node_name := NodeName, admitted_at := AdmittedAt}) ->
    new(NodeName, AdmittedAt).

new(NodeName, AdmittedAt) ->
    #node_admitted_v1{
        node_name = NodeName,
        admitted_at = AdmittedAt
    }.

-spec to_map(node_admitted_v1()) -> map().
to_map(#node_admitted_v1{
    node_name = NodeName,
    admitted_at = AdmittedAt
}) ->
    #{
        event_type => <<"node_admitted_v1">>,
        node_name => NodeName,
        admitted_at => AdmittedAt
    }.

-spec from_map(map()) -> {ok, node_admitted_v1()} | {error, term()}.
from_map(#{node_name := NN, admitted_at := AAt}) ->
    {ok, #node_admitted_v1{
        node_name = NN,
        admitted_at = AAt
    }};
from_map(_) ->
    {error, invalid_node_admitted_event}.
