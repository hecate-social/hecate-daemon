%%% @doc node_removed_v1 event
-module(node_removed_v1).

-behaviour(evoq_event).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([event_type/0]).

-record(node_removed_v1, {
    node_name  :: binary(),
    removed_at :: integer()
}).

-opaque node_removed_v1() :: #node_removed_v1{}.
-export_type([node_removed_v1/0]).

-spec new(binary(), integer()) -> node_removed_v1().
event_type() -> node_removed_v1.

new(#{node_name := NodeName, removed_at := RemovedAt}) ->
    new(NodeName, RemovedAt).

new(NodeName, RemovedAt) ->
    #node_removed_v1{
        node_name = NodeName,
        removed_at = RemovedAt
    }.

-spec to_map(node_removed_v1()) -> map().
to_map(#node_removed_v1{
    node_name = NodeName,
    removed_at = RemovedAt
}) ->
    #{
        event_type => <<"node_removed_v1">>,
        node_name => NodeName,
        removed_at => RemovedAt
    }.

-spec from_map(map()) -> {ok, node_removed_v1()} | {error, term()}.
from_map(#{node_name := NN, removed_at := RAt}) ->
    {ok, #node_removed_v1{
        node_name = NN,
        removed_at = RAt
    }};
from_map(_) ->
    {error, invalid_node_removed_event}.
