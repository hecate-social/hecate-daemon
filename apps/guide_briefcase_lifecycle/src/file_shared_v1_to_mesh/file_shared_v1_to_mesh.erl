%%% @doc Emitter: file_shared_v1 domain event -> mesh FACT.
%%%
%%% Subscribes via evoq_event_handler. The event carries a metadata
%%% snapshot (realm/path/size/etc) captured at share-time from the
%%% aggregate state, so the emitter can publish without a second trip
%%% to the event store or read model.
%%% @end
-module(file_shared_v1_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"file_shared_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(<<"file_shared_v1">>, Event, _Metadata, State) ->
    Data = maps:get(data, Event, Event),
    case gf(file_id, Data) of
        undefined ->
            logger:warning("[file_shared_v1_to_mesh] missing file_id: ~p",
                           [Event]);
        FileId ->
            publish(FileId, Data)
    end,
    {ok, State};
handle_event(_Type, _Event, _Meta, State) ->
    {ok, State}.

%%====================================================================
%% Internal
%%====================================================================

publish(FileId, Data) ->
    Realm = gf(realm, Data),
    Path  = gf(path,  Data),
    case {Realm, Path} of
        {undefined, _} ->
            logger:info("[file_shared_v1_to_mesh] skip ~s: pre-Phase-B "
                        "event (no metadata snapshot)", [FileId]);
        {_, undefined} ->
            logger:info("[file_shared_v1_to_mesh] skip ~s: no path", [FileId]);
        _ ->
            Fact = #{
                file_id      => FileId,
                realm        => Realm,
                path         => Path,
                mime_type    => gf(mime_type,    Data, <<"application/octet-stream">>),
                size         => gf(size,         Data, 0),
                content_hash => gf(content_hash, Data, <<>>),
                author_did   => gf(author_did,   Data, <<>>)
            },
            case share_file_in_mesh:share(Fact) of
                ok -> ok;
                {error, Reason} ->
                    logger:warning("[file_shared_v1_to_mesh] publish failed "
                                   "for ~s: ~p", [FileId, Reason])
            end
    end.

gf(Key, Map) -> gf(Key, Map, undefined).
gf(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
