%%% @doc Query: Find identity by MRI
-module(find_identity).

-export([execute/1]).

%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [execute/1]}).

%% @doc Find an identity by its MRI.
-spec execute(binary()) -> {ok, map()} | {error, not_found} | {error, term()}.
execute(MRI) ->
    Sql = io_lib:format(
        "SELECT mri, public_key, key_type, metadata, registered_at "
        "FROM identities "
        "WHERE mri = '~s'",
        [escape_sql(MRI)]
    ),

    case query_identities_store:query(iolist_to_binary(Sql)) of
        {ok, [[MRI, PublicKey, KeyType, MetadataJson, RegisteredAt]]} ->
            Metadata = json:decode(MetadataJson),
            {ok, #{
                mri => MRI,
                public_key => PublicKey,
                key_type => KeyType,
                metadata => Metadata,
                registered_at => RegisteredAt
            }};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
