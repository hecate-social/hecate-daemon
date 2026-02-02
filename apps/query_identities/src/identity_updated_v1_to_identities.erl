%%% @doc Projection: identity_updated_v1 -> identities table
%%% Updates an identity's metadata when updated.
-module(identity_updated_v1_to_identities).

-export([project/1]).

%% @doc Project identity_updated_v1 event by updating metadata.
-spec project(map()) -> ok | {error, term()}.
project(#{
    mri := MRI,
    metadata := Metadata,
    updated_at := UpdatedAt
}) ->
    MetadataJson = json:encode(Metadata),

    Sql = io_lib:format(
        "UPDATE identities SET metadata = '~s', updated_at = ~B "
        "WHERE mri = '~s'",
        [escape_sql(MetadataJson), UpdatedAt, escape_sql(MRI)]
    ),

    case query_identities_store:execute(iolist_to_binary(Sql)) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end;

project(_OtherEvent) ->
    {error, invalid_event_format}.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
