%%% @doc Query: get the full mesh graph (nodes + edges).
-module(get_mesh_graph).
-export([get/0]).

-spec get() -> {ok, map()} | {error, term()}.
get() ->
    NodesSql = "SELECT DISTINCT source_node FROM connections "
               "UNION "
               "SELECT DISTINCT target_node FROM connections",
    EdgesSql = "SELECT source_node, target_node, connected_at "
               "FROM connections",
    case query_node_lifecycle_store:query(NodesSql, []) of
        {ok, NodeRows} ->
            Nodes = [extract_node(R) || R <- NodeRows],
            case query_node_lifecycle_store:query(EdgesSql, []) of
                {ok, EdgeRows} ->
                    Edges = [edge_to_map(R) || R <- EdgeRows],
                    {ok, #{nodes => Nodes, edges => Edges}};
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

extract_node({Node}) -> Node;
extract_node([Node]) -> Node.

edge_to_map({Source, Target, ConnectedAt}) ->
    #{
        source => Source,
        target => Target,
        connected_at => ConnectedAt
    };
edge_to_map(Row) when is_list(Row) ->
    edge_to_map(list_to_tuple(Row)).
