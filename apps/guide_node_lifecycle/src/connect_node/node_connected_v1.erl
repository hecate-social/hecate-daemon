%%% @doc Event: node connected to another node on the mesh.
-module(node_connected_v1).
-export([new/3, to_map/1, from_map/1]).

-record(node_connected_v1, {
    source_node :: binary(),
    target_node :: binary(),
    connected_at :: integer()
}).

new(SourceNode, TargetNode, ConnectedAt) ->
    #node_connected_v1{source_node = SourceNode, target_node = TargetNode, connected_at = ConnectedAt}.

to_map(#node_connected_v1{source_node = Source, target_node = Target, connected_at = At}) ->
    #{
        event_type => <<"node_connected_v1">>,
        source_node => Source,
        target_node => Target,
        connected_at => At
    }.

from_map(#{source_node := Source, target_node := Target, connected_at := At}) ->
    {ok, #node_connected_v1{source_node = Source, target_node = Target, connected_at = At}};
from_map(_) ->
    {error, invalid_node_connected_event}.
