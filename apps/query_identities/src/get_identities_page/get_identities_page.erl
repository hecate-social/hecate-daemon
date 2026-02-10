%%% @doc Query: List all registered identities
-module(get_identities_page).

-export([execute/0, execute/1]).

%% @doc List all registered identities.
-spec execute() -> {ok, [map()]} | {error, term()}.
execute() ->
    execute(#{}).

%% @doc List identities with optional filters.
-spec execute(map()) -> {ok, [map()]} | {error, term()}.
execute(Opts) ->
    Limit = maps:get(limit, Opts, 100),
    Offset = maps:get(offset, Opts, 0),

    Sql = io_lib:format(
        "SELECT mri, public_key, key_type, metadata, registered_at, updated_at "
        "FROM identities "
        "ORDER BY registered_at DESC "
        "LIMIT ~B OFFSET ~B",
        [Limit, Offset]
    ),

    case query_identities_store:query(iolist_to_binary(Sql)) of
        {ok, Rows} ->
            Identities = [row_to_map(R) || R <- Rows],
            {ok, Identities};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

row_to_map({MRI, PublicKey, KeyType, MetadataJson, RegisteredAt, UpdatedAt}) ->
    Metadata = case MetadataJson of
        null -> #{};
        _ -> json:decode(MetadataJson)
    end,
    #{
        mri => MRI,
        public_key => PublicKey,
        key_type => KeyType,
        metadata => Metadata,
        registered_at => RegisteredAt,
        updated_at => UpdatedAt
    };
row_to_map([MRI, PublicKey, KeyType, MetadataJson, RegisteredAt, UpdatedAt]) ->
    row_to_map({MRI, PublicKey, KeyType, MetadataJson, RegisteredAt, UpdatedAt}).
