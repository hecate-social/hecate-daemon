%%% @doc Projects capability_updated_v1 events into the capabilities table.
-module(capability_updated_v1_to_capabilities).
-export([project/1]).

project(Data) when is_map(Data) ->
    CapMri = get_field(capability_mri, Data),
    RawTags = get_field(tags, Data),
    Tags = encode_json_list(RawTags),
    Description = get_field(description, Data),
    DemoProcedure = get_field(demo_procedure, Data),
    RawMetadata = get_field(metadata, Data),
    Metadata = encode_json(RawMetadata),
    UpdatedAt = get_field(updated_at, Data),

    Sql = "UPDATE capabilities "
          "SET tags = ?, description = ?, demo_procedure = ?, metadata = ?, updated_at = ? "
          "WHERE mri = ?",
    Params = [Tags, Description, DemoProcedure, Metadata, UpdatedAt, CapMri],
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

encode_json(undefined) -> <<"{}">>;
encode_json(Val) when is_map(Val) -> json:encode(Val);
encode_json(Val) when is_binary(Val) -> Val;
encode_json(_) -> <<"{}">>.

encode_json_list(undefined) -> <<"[]">>;
encode_json_list(Val) when is_list(Val) -> json:encode(Val);
encode_json_list(Val) when is_binary(Val) -> Val;
encode_json_list(_) -> <<"[]">>.
