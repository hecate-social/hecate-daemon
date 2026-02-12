%%% @doc Command: disconnect from a node on the mesh.
-module(disconnect_node_v1).
-export([new/2, to_map/1, from_map/1]).

-record(disconnect_node_v1, {
    source_node :: binary(),
    target_node :: binary()
}).

new(SourceNode, TargetNode) ->
    #disconnect_node_v1{source_node = SourceNode, target_node = TargetNode}.

to_map(#disconnect_node_v1{source_node = Source, target_node = Target}) ->
    #{source_node => Source, target_node => Target}.

from_map(#{source_node := Source, target_node := Target}) ->
    {ok, #disconnect_node_v1{source_node = Source, target_node = Target}};
from_map(_) ->
    {error, invalid_disconnect_node_command}.
