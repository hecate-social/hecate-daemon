%%% @doc Publish a briefcase file as a mesh integration fact.
%%%
%%% Called after a successful local `upload_file_v1` dispatch. Publishes
%%% `file_shared_v1` to the realm-scoped topic:
%%%     `<realm>.briefcase.file_shared`
%%%
%%% Subscribers on other peers in the realm receive this fact and may
%%% fetch the content via the `<realm>.briefcase.get_chunk` RPC.
%%%
%%% Integration fact schema (stable contract; distinct from internal
%%% `file_uploaded_v1` domain event):
%%%
%%%     #{ event_type    => <<"file_shared_v1">>,
%%%        file_id       => binary(),     %% BLAKE3 hex of content
%%%        realm         => binary(),
%%%        path          => binary(),
%%%        mime_type     => binary(),
%%%        size          => non_neg_integer(),
%%%        content_hash  => binary(),
%%%        author_did    => binary(),
%%%        shared_at     => integer() }   %% wallclock ms
%%%
%%% Fire-and-forget on the caller's behalf — never blocks the command
%%% dispatch path on mesh availability.
%%% @end
-module(share_file_in_mesh).

-export([share/1, topic/1]).

-spec share(map()) -> ok | {error, term()}.
share(#{file_id := FileId, realm := Realm, path := Path,
        mime_type := MimeType, size := Size, content_hash := Hash,
        author_did := AuthorDid}) ->
    Fact = #{
        event_type    => <<"file_shared_v1">>,
        file_id       => FileId,
        realm         => Realm,
        path          => Path,
        mime_type     => MimeType,
        size          => Size,
        content_hash  => Hash,
        author_did    => AuthorDid,
        shared_at     => erlang:system_time(millisecond)
    },
    Topic = topic(Realm),
    try hecate_mesh_client:publish(Topic, Fact) of
        ok -> ok;
        {error, Reason} ->
            logger:warning("[briefcase] mesh publish failed for ~s: ~p",
                           [FileId, Reason]),
            {error, Reason};
        Other ->
            logger:warning("[briefcase] mesh publish unexpected: ~p", [Other]),
            {error, Other}
    catch Class:Error ->
        logger:warning("[briefcase] mesh publish crashed: ~p:~p",
                       [Class, Error]),
        {error, {Class, Error}}
    end;
share(_Incomplete) ->
    {error, missing_fields}.

-spec topic(binary()) -> binary().
topic(Realm) when is_binary(Realm) ->
    <<Realm/binary, ".briefcase.file_shared">>.
