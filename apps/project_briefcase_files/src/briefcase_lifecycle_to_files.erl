%%% @doc Merged projection: briefcase lifecycle events -> files ETS.
%%%
%%% Phase A handles: `file_uploaded_v1` (creates row, privacy=private),
%%% `file_shared_v1` (flips privacy=shared), `file_unshared_v1` (back to
%%% private). Later phases add revise/move/archive/purge + remote
%%% placeholder/cached states.
%%% @end
-module(briefcase_lifecycle_to_files).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

-define(TABLE, briefcase_files).

interested_in() ->
    [<<"file_uploaded_v1">>,
     <<"file_shared_v1">>,
     <<"file_unshared_v1">>,
     <<"file_announced_v1">>,
     %% Legacy (synchronous Phase E) — kept for replay safety.
     <<"file_cached_v1">>,
     %% Async download model.
     <<"file_download_started_v1">>,
     <<"file_download_completed_v1">>,
     <<"file_download_failed_v1">>,
     <<"file_evicted_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"file_uploaded_v1">>            -> project_file_uploaded(Data, State, RM);
        <<"file_shared_v1">>              -> project_privacy_change(Data, <<"shared">>, State, RM);
        <<"file_unshared_v1">>            -> project_privacy_change(Data, <<"private">>, State, RM);
        <<"file_announced_v1">>           -> project_file_announced(Data, State, RM);
        %% Legacy: replay treats file_cached_v1 identically to
        %% file_download_completed_v1.
        <<"file_cached_v1">>              -> project_file_completed(Data, State, RM);
        <<"file_download_started_v1">>    -> project_file_download_started(Data, State, RM);
        <<"file_download_completed_v1">>  -> project_file_completed(Data, State, RM);
        <<"file_download_failed_v1">>     -> project_file_download_failed(Data, State, RM);
        <<"file_evicted_v1">>             -> project_file_evicted(Data, State, RM);
        _                                  -> {ok, State, RM}
    end.

%% ===================================================================
%% file_uploaded_v1 — insert new file into read model (private by default)
%% ===================================================================

project_file_uploaded(Data, State, RM) ->
    FileId = gf(file_id, Data),
    Entry = #{
        file_id      => FileId,
        realm        => gf(realm, Data),
        path         => gf(path, Data),
        mime_type    => gf(mime_type, Data),
        size         => gf(size, Data),
        content_hash => gf(content_hash, Data),
        author_did   => gf(author_did, Data),
        uploaded_at  => gf(uploaded_at, Data),
        privacy      => <<"private">>,
        presence     => <<"local">>,
        status       => 1,
        status_label => <<"Uploaded">>
    },
    {ok, RM2} = evoq_read_model:put(FileId, Entry, RM),
    {ok, State, RM2}.

%% ===================================================================
%% file_announced_v1 — remote peer's shared file, placeholder row
%% ===================================================================

project_file_announced(Data, State, RM) ->
    FileId = gf(file_id, Data),
    Entry = #{
        file_id      => FileId,
        realm        => gf(realm, Data),
        path         => gf(path, Data),
        mime_type    => gf(mime_type, Data),
        size         => gf(size, Data),
        content_hash => gf(content_hash, Data),
        author_did   => gf(author_did, Data),
        uploaded_at  => gf(announced_at, Data),
        privacy      => <<"shared">>,
        presence     => <<"remote">>,
        status       => 64,  %% FILE_ANNOUNCED
        status_label => <<"Placeholder">>
    },
    {ok, RM2} = evoq_read_model:put(FileId, Entry, RM),
    {ok, State, RM2}.

%% ===================================================================
%% file_download_started_v1 — async pull begins (transient state)
%% ===================================================================

project_file_download_started(Data, State, RM) ->
    FileId = gf(file_id, Data),
    case evoq_read_model:get(FileId, RM) of
        {ok, Entry} ->
            Updated = Entry#{
                presence     => <<"downloading">>,
                status_label => <<"Downloading">>,
                download_started_at => gf(started_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(FileId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% ===================================================================
%% file_download_completed_v1 (and legacy file_cached_v1) —
%% ciphertext downloaded + persisted locally
%% ===================================================================

project_file_completed(Data, State, RM) ->
    FileId = gf(file_id, Data),
    case evoq_read_model:get(FileId, RM) of
        {ok, Entry} ->
            Cleared = maps:without([download_started_at,
                                    download_failed_at,
                                    download_failure_reason], Entry),
            Updated = Cleared#{
                presence     => <<"cached">>,
                status_label => <<"Cached">>,
                cache_size   => gf(cache_size, Data),
                cached_at    => completed_at_or_legacy(Data),
                source_realm => gf(source_realm, Data)
            },
            {ok, RM2} = evoq_read_model:put(FileId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% Legacy file_cached_v1 events used `cached_at`; the new event uses
%% `completed_at`. Pick whichever is present.
completed_at_or_legacy(Data) ->
    case gf(completed_at, Data) of
        undefined -> gf(cached_at, Data);
        At        -> At
    end.

%% ===================================================================
%% file_download_failed_v1 — pull failed; back to placeholder
%% ===================================================================

project_file_download_failed(Data, State, RM) ->
    FileId = gf(file_id, Data),
    case evoq_read_model:get(FileId, RM) of
        {ok, Entry} ->
            Cleared = maps:without([download_started_at], Entry),
            Updated = Cleared#{
                presence     => <<"remote">>,
                status_label => <<"Download failed">>,
                download_failed_at => gf(failed_at, Data),
                download_failure_reason => gf(reason, Data)
            },
            {ok, RM2} = evoq_read_model:put(FileId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% ===================================================================
%% file_evicted_v1 — cached ciphertext removed from disk
%% ===================================================================

project_file_evicted(Data, State, RM) ->
    FileId = gf(file_id, Data),
    case evoq_read_model:get(FileId, RM) of
        {ok, Entry} ->
            Cleared = maps:without([cache_size, cached_at, source_realm],
                                   Entry),
            Updated = Cleared#{
                presence     => <<"remote">>,
                status_label => <<"Placeholder">>,
                evicted_at   => gf(evicted_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(FileId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

%% ===================================================================
%% file_shared_v1 / file_unshared_v1 — flip the privacy flag
%% ===================================================================

project_privacy_change(Data, NewPrivacy, State, RM) ->
    FileId = gf(file_id, Data),
    case evoq_read_model:get(FileId, RM) of
        {ok, Entry} ->
            Entry2 = Entry#{privacy => NewPrivacy},
            {ok, RM2} = evoq_read_model:put(FileId, Entry2, RM),
            {ok, State, RM2};
        {error, not_found} ->
            %% Privacy change for unknown file — ignore; file_uploaded
            %% event is the birth record. Out-of-order delivery would
            %% reconcile on replay.
            {ok, State, RM}
    end.

%% ===================================================================
%% Helpers
%% ===================================================================

get_event_type(#{event_type := T}) -> T;
get_event_type(#{<<"event_type">> := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, undefined)
    end.
