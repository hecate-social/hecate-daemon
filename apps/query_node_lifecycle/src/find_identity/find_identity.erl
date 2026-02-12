%%% @doc Query: find an identity by MRI.
-module(find_identity).
-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(Mri) ->
    Sql = "SELECT mri, public_key, key_type, metadata, "
          "registered_at, updated_at "
          "FROM identities WHERE mri = ?1",
    case query_node_lifecycle_store:query(Sql, [Mri]) of
        {ok, [Row]} ->
            {ok, row_to_map(Row)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

row_to_map({Mri, PublicKey, KeyType, Metadata, RegisteredAt, UpdatedAt}) ->
    #{
        mri => Mri,
        public_key => PublicKey,
        key_type => KeyType,
        metadata => decode_json(Metadata),
        registered_at => RegisteredAt,
        updated_at => UpdatedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).

decode_json(null) -> null;
decode_json(undefined) -> null;
decode_json(Val) when is_binary(Val) -> json:decode(Val);
decode_json(Val) -> Val.
