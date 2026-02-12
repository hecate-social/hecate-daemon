%%% @doc Query: list identities with pagination.
-module(get_identities_page).
-export([get/1]).

-spec get(map()) -> {ok, [map()]} | {error, term()}.
get(Filters) ->
    Limit = maps:get(limit, Filters, 100),
    Offset = maps:get(offset, Filters, 0),
    Sql = "SELECT mri, public_key, key_type, metadata, "
          "registered_at, updated_at "
          "FROM identities "
          "ORDER BY registered_at DESC "
          "LIMIT ?1 OFFSET ?2",
    case query_node_lifecycle_store:query(Sql, [Limit, Offset]) of
        {ok, Rows} ->
            {ok, [row_to_map(R) || R <- Rows]};
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
