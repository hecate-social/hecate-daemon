%%% @doc Projects node_connected_v1 events into the connections table.
-module(node_connected_v1_to_connections).
-export([project/1]).

project(Data) when is_map(Data) ->
    SourceNode = get_field(source_node, Data),
    TargetNode = get_field(target_node, Data),
    ConnectedAt = get_field(connected_at, Data),

    Sql = "INSERT OR REPLACE INTO connections "
          "(source_node, target_node, connected_at) "
          "VALUES (?, ?, ?)",
    Params = [SourceNode, TargetNode, ConnectedAt],
    query_node_lifecycle_store:execute(Sql, Params);
project(_) -> ok.

%% ===================================================================
%% Internal
%% ===================================================================

get_field(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map, undefined)
    end.
