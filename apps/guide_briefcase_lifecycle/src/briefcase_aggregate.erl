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

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.
