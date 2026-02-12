%%% @doc Query: list mesh connections with pagination.
-module(get_connections_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT source_node, target_node, connected_at "
          "FROM connections "
          "ORDER BY connected_at DESC "
          "LIMIT ?1 OFFSET ?2",
    case query_node_lifecycle_store:query(Sql, [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({SourceNode, TargetNode, ConnectedAt}) ->
    #{
        source_node => SourceNode,
        target_node => TargetNode,
        connected_at => ConnectedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).
