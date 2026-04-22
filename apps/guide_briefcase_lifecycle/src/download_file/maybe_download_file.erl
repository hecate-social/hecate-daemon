%%% @doc Handler for download_file_v1.
%%%
%%% Orchestrates:
%%%   1. Validate the aggregate state (expects FILE_ANNOUNCED without
%%%      FILE_CACHED — enforced at the aggregate layer before we run).
%%%   2. Enforce the open-path guard — skip the download if the
%%%      license state is stale / revoked (no point caching bytes we
%%%      can't decrypt).
%%%   3. Call `download_file_client:fetch/2` to stream ciphertext frames
%%%      into the cache store.
%%%   4. Emit `file_cached_v1` with the cache size + frame count.
%%%
%%% The download is a side effect performed BEFORE the event is
%%% emitted — so the event accurately records a completed cache. On
%%% replay the side effect does not re-run; the cached bytes are
%%% either still on disk or the user needs to re-download explicitly.
%%% @end
-module(maybe_download_file).

-export([handle_with_state/2, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").
-include("briefcase_state.hrl").

-spec handle_with_state(map(), #briefcase_state{}) ->
    {ok, [map()]} | {error, term()}.
handle_with_state(Payload, State) ->
    FileId = maps:get(file_id, Payload),
    Realm  = State#briefcase_state.realm,
    case validate_realm(Realm) of
        ok ->
            guard_and_download(FileId, Realm);
        {error, _} = Err ->
            Err
    end.

-spec dispatch(download_file_v1:download_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId   = download_file_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    Payload  = download_file_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = download_file_v1,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => download_file_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).

%%====================================================================
%% Internal
%%====================================================================

validate_realm(undefined) -> {error, realm_not_set};
validate_realm(R) when is_binary(R), byte_size(R) > 0 -> ok;
validate_realm(_) -> {error, realm_not_set}.

guard_and_download(FileId, Realm) ->
    case hecate_license_guard:can_open_file(FileId, Realm) of
        ok ->
            do_fetch(FileId, Realm);
        {error, Reason} ->
            {error, {license_refused, Reason}}
    end.

do_fetch(FileId, Realm) ->
    case download_file_client:fetch(Realm, FileId) of
        {ok, #{bytes_written := Size, frames := Frames}} ->
            build_event(FileId, Realm, Size, Frames);
        {error, _} = Err ->
            Err
    end.

build_event(FileId, Realm, Size, Frames) ->
    CachedAt = erlang:system_time(millisecond),
    {ok, Event} = file_cached_v1:new(#{
        file_id      => FileId,
        source_realm => Realm,
        cache_size   => Size,
        frames       => Frames,
        cached_at    => CachedAt}),
    {ok, [file_cached_v1:to_map(Event)]}.
