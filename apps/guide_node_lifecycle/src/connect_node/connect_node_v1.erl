%%% @doc Command: connect to another node on the mesh.
-module(connect_node_v1).
-export([new/2, to_map/1, from_map/1]).

-record(connect_node_v1, {
    source_node :: binary(),
    target_node :: binary()
}).

-opaque connect_node_v1() :: #connect_node_v1{}.
-export_type([connect_node_v1/0]).

new(SourceNode, TargetNode) ->
    #connect_node_v1{source_node = SourceNode, target_node = TargetNode}.

to_map(#connect_node_v1{source_node = Source, target_node = Target}) ->
    #{source_node => Source, target_node => Target}.

from_map(#{source_node := Source, target_node := Target}) ->
    {ok, #connect_node_v1{source_node = Source, target_node = Target}};
from_map(_) ->
    {error, invalid_connect_node_command}.
