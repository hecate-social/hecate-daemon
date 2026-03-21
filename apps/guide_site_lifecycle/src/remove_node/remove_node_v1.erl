%%% @doc remove_node_v1 command
-module(remove_node_v1).

-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(remove_node_v1, {
    node_name  :: binary(),
    removed_at :: integer()
}).

-opaque remove_node_v1() :: #remove_node_v1{}.
-export_type([remove_node_v1/0]).

-spec new(binary(), integer()) -> remove_node_v1().
command_type() -> remove_node.

new(#{node_name := NodeName, removed_at := RemovedAt}) ->
    {ok, new(NodeName, RemovedAt)};
new(_) ->
    {error, missing_fields}.

new(NodeName, RemovedAt) ->
    #remove_node_v1{
        node_name = NodeName,
        removed_at = RemovedAt
    }.

-spec to_map(remove_node_v1()) -> map().
to_map(#remove_node_v1{
    node_name = NodeName,
    removed_at = RemovedAt
}) ->
    #{
        node_name => NodeName,
        removed_at => RemovedAt
    }.

-spec from_map(map()) -> {ok, remove_node_v1()} | {error, term()}.
from_map(#{node_name := NN, removed_at := RAt}) ->
    {ok, #remove_node_v1{
        node_name = NN,
        removed_at = RAt
    }};
from_map(_) ->
    {error, invalid_remove_node_command}.
