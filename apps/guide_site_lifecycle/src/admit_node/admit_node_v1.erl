%%% @doc admit_node_v1 command
-module(admit_node_v1).

-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).

-record(admit_node_v1, {
    node_name   :: binary(),
    admitted_at :: integer()
}).

-opaque admit_node_v1() :: #admit_node_v1{}.
-export_type([admit_node_v1/0]).

-spec new(binary(), integer()) -> admit_node_v1().
command_type() -> admit_node.

new(#{node_name := NodeName, admitted_at := AdmittedAt}) ->
    {ok, new(NodeName, AdmittedAt)};
new(_) ->
    {error, missing_fields}.

new(NodeName, AdmittedAt) ->
    #admit_node_v1{
        node_name = NodeName,
        admitted_at = AdmittedAt
    }.

-spec to_map(admit_node_v1()) -> map().
to_map(#admit_node_v1{
    node_name = NodeName,
    admitted_at = AdmittedAt
}) ->
    #{
        node_name => NodeName,
        admitted_at => AdmittedAt
    }.

-spec from_map(map()) -> {ok, admit_node_v1()} | {error, term()}.
from_map(#{node_name := NN, admitted_at := AAt}) ->
    {ok, #admit_node_v1{
        node_name = NN,
        admitted_at = AAt
    }};
from_map(_) ->
    {error, invalid_admit_node_command}.
