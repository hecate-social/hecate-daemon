%%% @doc Aggregate for briefcase file lifecycle.
%%%
%%% One aggregate per file. Stream: `briefcase-{file_id}`.
%%% file_id is a BLAKE3 of (realm || path || author_did || wallclock_ms)
%%% generated at upload time.
%%% @end
-module(briefcase_aggregate).
-behaviour(evoq_aggregate).

-include("briefcase_state.hrl").
-include("briefcase_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/1]).

-spec state_module() -> module().
state_module() -> briefcase_state.

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

init(AggregateId) ->
    {ok, briefcase_state:new(AggregateId)}.

%% @doc Build stream id from file_id.
-spec stream_id(binary()) -> binary().
stream_id(FileId) when is_binary(FileId) ->
    <<"briefcase-", FileId/binary>>.

%% @doc Execute command — State FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Evoq callback: apply/2 — State FIRST. Delegates to state module.
apply(State, Event) ->
    briefcase_state:apply_event(State, Event).

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(upload_file, State, Payload) ->
    case State#briefcase_state.status band ?FILE_UPLOADED of
        0 -> maybe_upload_file:handle_from_map(Payload);
        _ -> {error, already_uploaded}
    end;

do_execute(share_file_v1, State, Payload) ->
    Status = State#briefcase_state.status,
    Uploaded = (Status band ?FILE_UPLOADED) =/= 0,
    Shared   = (Status band ?FILE_SHARED)   =/= 0,
    case {Uploaded, Shared} of
        {false, _}    -> {error, not_uploaded};
        {true,  true} -> {error, already_shared};
        {true,  false} -> maybe_share_file:handle_with_state(Payload, State)
    end;

do_execute(unshare_file_v1, State, Payload) ->
    case State#briefcase_state.status band ?FILE_SHARED of
        0 -> {error, not_shared};
        _ -> maybe_unshare_file:handle_from_map(Payload)
    end;

%% announce_file is the birth event for remote files (peer announced a
%% file we've never seen). Only allowed on empty aggregates — if we
%% already uploaded (local origin) or already announced, skip.
do_execute(announce_file_v1, State, Payload) ->
    case State#briefcase_state.status of
        0 -> maybe_announce_file:handle_from_map(Payload);
        _ -> {error, already_present}
    end;

%% Phase E async model: download_file_v1 is the user's intent. The
%% handler emits file_download_started_v1 (no I/O); the PM
%% on_file_download_started_fetch_bytes spawns the supervised worker
%% which later dispatches complete_file_download_v1 or
%% fail_file_download_v1 from the worker process.
%%
%% Gates: must be FILE_ANNOUNCED, must NOT be FILE_UPLOADED (owned
%% files don't download), must NOT be FILE_CACHED (already have it),
%% must NOT be FILE_DOWNLOADING (worker already in flight). The
%% downloading guard provides idempotency for repeated POSTs.
do_execute(download_file_v1, State, Payload) ->
    Status = State#briefcase_state.status,
    Announced   = (Status band ?FILE_ANNOUNCED)   =/= 0,
    Cached      = (Status band ?FILE_CACHED)      =/= 0,
    Uploaded    = (Status band ?FILE_UPLOADED)    =/= 0,
    Downloading = (Status band ?FILE_DOWNLOADING) =/= 0,
    if
        Uploaded       -> {error, locally_uploaded};
        not Announced  -> {error, not_announced};
        Cached         -> {error, already_cached};
        Downloading    -> {error, already_downloading};
        true           -> maybe_download_file:handle_with_state(Payload, State)
    end;

%% Internal: worker dispatches this when the cache write completes.
%% Aggregate gates on FILE_DOWNLOADING — if it's not set, either the
%% download was never started (bug) or a cancel raced ahead.
do_execute(complete_file_download_v1, State, Payload) ->
    Status = State#briefcase_state.status,
    case (Status band ?FILE_DOWNLOADING) =/= 0 of
        true  -> maybe_complete_file_download:handle_from_map(Payload);
        false -> {error, not_downloading}
    end;

%% Internal: worker dispatches this on fetch failure. Same gate.
do_execute(fail_file_download_v1, State, Payload) ->
    Status = State#briefcase_state.status,
    case (Status band ?FILE_DOWNLOADING) =/= 0 of
        true  -> maybe_fail_file_download:handle_from_map(Payload);
        false -> {error, not_downloading}
    end;

%% Phase E: drop cached ciphertext from disk. Valid only on
%% FILE_CACHED files (remote + cached). Emitting file_evicted_v1
%% clears the bit — a re-download re-fills the cache.
do_execute(evict_file_v1, State, Payload) ->
    Status = State#briefcase_state.status,
    case (Status band ?FILE_CACHED) =/= 0 of
        true  -> maybe_evict_file:handle_with_state(Payload, State);
        false -> {error, not_cached}
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.
