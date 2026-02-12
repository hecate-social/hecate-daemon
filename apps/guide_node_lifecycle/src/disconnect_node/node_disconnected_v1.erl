%%% @doc Event: node disconnected from another node.
-module(node_disconnected_v1).
-export([new/3, to_map/1, from_map/1]).

-record(node_disconnected_v1, {
    source_node :: binary(),
    target_node :: binary(),
    disconnected_at :: integer()
}).

new(SourceNode, TargetNode, DisconnectedAt) ->
    #node_disconnected_v1{source_node = SourceNode, target_node = TargetNode, disconnected_at = DisconnectedAt}.

to_map(#node_disconnected_v1{source_node = Source, target_node = Target, disconnected_at = At}) ->
    #{
        event_type => <<"node_disconnected_v1">>,
        source_node => Source,
        target_node => Target,
        disconnected_at => At
    }.

from_map(#{source_node := Source, target_node := Target, disconnected_at := At}) ->
    {ok, #node_disconnected_v1{source_node = Source, target_node = Target, disconnected_at = At}};
from_map(_) ->
    {error, invalid_node_disconnected_event}.
