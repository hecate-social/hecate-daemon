%%% @doc Projects capability_retracted_v1 events into the capabilities table.
-module(capability_retracted_v1_to_capabilities).
-export([project/1]).

project(Data) when is_map(Data) ->
    CapMri = get_field(capability_mri, Data),
    RetractedAt = get_field(retracted_at, Data),

    Sql = "UPDATE capabilities SET retracted_at = ? WHERE mri = ?",
    Params = [RetractedAt, CapMri],
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
