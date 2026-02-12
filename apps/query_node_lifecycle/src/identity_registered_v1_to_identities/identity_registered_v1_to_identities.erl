%%% @doc Projects identity_registered_v1 events into the identities table.
-module(identity_registered_v1_to_identities).
-export([project/1]).

project(Data) when is_map(Data) ->
    Mri = get_field(mri, Data),
    PublicKey = get_field(public_key, Data),
    KeyType = get_field(key_type, Data),
    RawMetadata = get_field(metadata, Data),
    Metadata = encode_json(RawMetadata),
    RegisteredAt = get_field(registered_at, Data),

    Sql = "INSERT OR REPLACE INTO identities "
          "(mri, public_key, key_type, metadata, registered_at) "
          "VALUES (?, ?, ?, ?, ?)",
    Params = [Mri, PublicKey, KeyType, Metadata, RegisteredAt],
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
