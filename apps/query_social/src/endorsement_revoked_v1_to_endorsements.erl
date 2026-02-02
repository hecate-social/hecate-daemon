%%% @doc Projection: endorsement_revoked_v1 -> endorsements table
%%% Marks an endorsement as revoked when an agent revokes their endorsement.
-module(endorsement_revoked_v1_to_endorsements).

-export([project/1]).

%% @doc Project endorsement_revoked_v1 event by setting revoked_at timestamp.
-spec project(map()) -> ok | {error, term()}.
project(#{
    endorser_identity := Endorser,
    capability_mri := MRI,
    revoked_at := RevokedAt
}) ->
    Sql = io_lib:format(
        "UPDATE endorsements SET revoked_at = ~B "
        "WHERE endorser_identity = '~s' AND capability_mri = '~s'",
        [RevokedAt, escape_sql(Endorser), escape_sql(MRI)]
    ),

    case query_social_store:execute(iolist_to_binary(Sql)) of
        ok -> ok;
        {error, Reason} -> {error, Reason}
    end;

project(_OtherEvent) ->
    {error, invalid_event_format}.

%% Internal functions

escape_sql(Binary) when is_binary(Binary) ->
    binary:replace(Binary, <<"'">>, <<"''">>, [global]).
