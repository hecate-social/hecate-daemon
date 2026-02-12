%%% @doc Projects node_disconnected_v1 events by deleting from the connections table.
-module(node_disconnected_v1_to_connections).
-export([project/1]).

project(Data) when is_map(Data) ->
    SourceNode = get_field(source_node, Data),
    TargetNode = get_field(target_node, Data),

    Sql = "DELETE FROM connections WHERE source_node = ? AND target_node = ?",
    Params = [SourceNode, TargetNode],
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
