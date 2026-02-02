%%% @doc Projection: identity_registered_v1 → identities table
-module(identity_registered_v1_to_identities).

-export([project/1]).

%% @doc Project identity_registered_v1 event to identities table.
-spec project(map()) -> ok | {error, term()}.
project(#{
    event_type := <<"identity_registered_v1">>,
    mri := MRI,
    public_key := PublicKey,
    key_type := KeyType,
    metadata := Metadata,
    registered_at := RegisteredAt
}) ->
    MetadataJson = json:encode(Metadata),

    Sql = io_lib:format(
        "INSERT OR REPLACE INTO identities "
        "(mri, public_key, key_type, metadata, registered_at) "
        "VALUES ('~s', '~s', '~s', '~s', ~B)",
        [escape_sql(MRI), escape_sql(PublicKey), escape_sql(KeyType),
         escape_sql(MetadataJson), RegisteredAt]
    ),

    case query_identities_store:execute(iolist_to_binary(Sql)) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end;

project(_OtherEvent) ->
    ok.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
