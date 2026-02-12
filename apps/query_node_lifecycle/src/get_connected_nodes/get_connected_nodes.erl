%%% @doc Query: get nodes connected to a given source node.
-module(get_connected_nodes).
-export([get/1]).

-spec get(binary()) -> {ok, [map()]} | {error, term()}.
get(SourceNode) ->
    Sql = "SELECT target_node, connected_at "
          "FROM connections "
          "WHERE source_node = ?1 "
          "ORDER BY connected_at DESC",
    case query_node_lifecycle_store:query(Sql, [SourceNode]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({TargetNode, ConnectedAt}) ->
    #{
        target_node => TargetNode,
        connected_at => ConnectedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).
