%%% @doc State module for briefcase file aggregate.
%%%
%%% Owns the state record, event folding, and serialization. One
%%% aggregate instance per file — stream id is `briefcase-{file_id}`.
%%% @end
-module(briefcase_state).

-behaviour(evoq_state).

-include("briefcase_state.hrl").
-include("briefcase_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #briefcase_state{}.
-export_type([state/0]).

%% @doc Create initial empty state for a given aggregate id (file_id).
-spec new(binary()) -> state().
new(FileId) ->
    #briefcase_state{
        file_id      = FileId,
        chunk_hashes = [],
        status       = 0
    }.

%% @doc Apply event to state. State FIRST, Event SECOND.
-spec apply_event(state(), map()) -> state().
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% @doc Serialize state to map.
-spec to_map(state()) -> map().
to_map(#briefcase_state{} = S) ->
    #{
        file_id      => S#briefcase_state.file_id,
        realm        => S#briefcase_state.realm,
        path         => S#briefcase_state.path,
        mime_type    => S#briefcase_state.mime_type,
        size         => S#briefcase_state.size,
        content_hash => S#briefcase_state.content_hash,
        chunk_hashes => S#briefcase_state.chunk_hashes,
        author_did   => S#briefcase_state.author_did,
        status       => S#briefcase_state.status,
        uploaded_at  => S#briefcase_state.uploaded_at,
        revised_at   => S#briefcase_state.revised_at
    }.

%% ===================================================================
%% Event folding
%% ===================================================================

do_apply(<<"file_uploaded_v1">>, State, #{data := Data}) ->
    apply_file_uploaded(State, Data);
do_apply(<<"file_uploaded_v1">>, State, Data) ->
    apply_file_uploaded(State, Data);
do_apply(<<"file_shared_v1">>, State, #{data := _}) ->
    apply_file_shared(State);
do_apply(<<"file_shared_v1">>, State, _Data) ->
    apply_file_shared(State);
do_apply(<<"file_unshared_v1">>, State, #{data := _}) ->
    apply_file_unshared(State);
do_apply(<<"file_unshared_v1">>, State, _Data) ->
    apply_file_unshared(State);
do_apply(<<"file_announced_v1">>, State, #{data := Data}) ->
    apply_file_announced(State, Data);
do_apply(<<"file_announced_v1">>, State, Data) ->
    apply_file_announced(State, Data);
do_apply(_UnknownEventType, State, _Event) ->
    State.

apply_file_uploaded(State, Data) ->
    State#briefcase_state{
        realm        = gf(realm, Data, State#briefcase_state.realm),
        path         = gf(path, Data, State#briefcase_state.path),
        mime_type    = gf(mime_type, Data, State#briefcase_state.mime_type),
        size         = gf(size, Data, State#briefcase_state.size),
        content_hash = gf(content_hash, Data, State#briefcase_state.content_hash),
        chunk_hashes = gf(chunk_hashes, Data, State#briefcase_state.chunk_hashes),
        author_did   = gf(author_did, Data, State#briefcase_state.author_did),
        uploaded_at  = gf(uploaded_at, Data, State#briefcase_state.uploaded_at),
        status       = evoq_bit_flags:set(State#briefcase_state.status, ?FILE_UPLOADED)
    }.

apply_file_shared(State) ->
    State#briefcase_state{
        status = evoq_bit_flags:set(State#briefcase_state.status, ?FILE_SHARED)
    }.

apply_file_unshared(State) ->
    State#briefcase_state{
        status = evoq_bit_flags:unset(State#briefcase_state.status, ?FILE_SHARED)
    }.

%% Remote-origin birth: we learn about a peer's file via mesh FACT.
%% Populates metadata + marks FILE_ANNOUNCED. No content yet (that's
%% the FILE_CACHED transition, Phase E).
apply_file_announced(State, Data) ->
    State#briefcase_state{
        realm        = gf(realm,        Data, State#briefcase_state.realm),
        path         = gf(path,         Data, State#briefcase_state.path),
        mime_type    = gf(mime_type,    Data, State#briefcase_state.mime_type),
        size         = gf(size,         Data, State#briefcase_state.size),
        content_hash = gf(content_hash, Data, State#briefcase_state.content_hash),
        author_did   = gf(author_did,   Data, State#briefcase_state.author_did),
        uploaded_at  = gf(announced_at, Data, State#briefcase_state.uploaded_at),
        status       = evoq_bit_flags:set(State#briefcase_state.status, ?FILE_ANNOUNCED)
    }.

%% @private Get field from map with default (atom or binary key).
gf(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
