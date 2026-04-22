%%% @doc Streaming client: pulls ciphertext frames from a peer's
%%% `<realm>.briefcase.get_chunk_stream` RPC and writes them straight
%%% to the local cache as `cache/{XX}/{FileId}.enc`.
%%%
%%% Plaintext is NEVER materialised on this side — the receiver
%%% persists the exact frame bytes it received. Phase F decrypt reads
%%% them back chunk-by-chunk using the license's sealed CEK.
%%%
%%% Returns on success: `{ok, #{bytes_written, frames}}`. On failure
%%% the partial cache file is deleted so replay / retry starts clean.
%%% @end
-module(download_file_client).

-export([fetch/2, fetch/3]).

-define(DEFAULT_TIMEOUT_MS, 120000).
-define(CHUNK_RECV_TIMEOUT_MS, 30000).

-type fetch_opts() :: #{open_timeout_ms => pos_integer(),
                        chunk_timeout_ms => pos_integer()}.
-type fetch_result() :: {ok, #{bytes_written := non_neg_integer(),
                               frames := non_neg_integer()}}
                      | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec fetch(binary(), binary()) -> fetch_result().
fetch(Realm, FileId) ->
    fetch(Realm, FileId, #{}).

-spec fetch(binary(), binary(), fetch_opts()) -> fetch_result().
fetch(Realm, FileId, Opts)
  when is_binary(Realm), is_binary(FileId), is_map(Opts) ->
    Proc = <<Realm/binary, ".briefcase.get_chunk_stream">>,
    OpenTimeout = maps:get(open_timeout_ms, Opts, ?DEFAULT_TIMEOUT_MS),
    ChunkTimeout = maps:get(chunk_timeout_ms, Opts, ?CHUNK_RECV_TIMEOUT_MS),
    case open_stream(Proc, FileId, OpenTimeout) of
        {ok, Stream} ->
            run_download(Stream, FileId, ChunkTimeout);
        {error, _} = Err ->
            Err
    end.

%%====================================================================
%% Internal
%%====================================================================

open_stream(Proc, FileId, Timeout) ->
    Args = #{<<"file_id">> => FileId},
    case hecate_mesh_client:call_stream(Proc, Args, #{}, Timeout) of
        {ok, Stream}     -> {ok, Stream};
        {error, _} = Err -> Err
    end.

run_download(Stream, FileId, ChunkTimeout) ->
    case briefcase_cache_store:open_writer(FileId) of
        {ok, Fd} ->
            Result = pump_frames(Stream, Fd, FileId, ChunkTimeout,
                                  <<>>, 0, 0),
            ok = briefcase_cache_store:close_writer(Fd),
            finalize(FileId, Result);
        {error, _} = Err ->
            _ = drain_remaining(Stream, ChunkTimeout),
            Err
    end.

%% Pump loop:
%%   - Receive a macula chunk (arbitrary byte boundary).
%%   - Accumulate into buffer, peel whole frames, write each frame to
%%     the cache (including its length prefix).
%%   - On an EOF frame: write an EOF marker too and return success.
%%   - Carry partial bytes across iterations until the next chunk
%%     completes a frame.
pump_frames(Stream, Fd, FileId, ChunkTimeout, Buf, BytesOut, Frames) ->
    case macula:recv(Stream, ChunkTimeout) of
        {chunk, Bin} ->
            NewBuf = <<Buf/binary, Bin/binary>>,
            case peel_and_write(NewBuf, Fd, BytesOut, Frames) of
                {continue, BufLeft, BytesOut2, Frames2} ->
                    pump_frames(Stream, Fd, FileId, ChunkTimeout,
                                BufLeft, BytesOut2, Frames2);
                {done, BytesOut2, Frames2} ->
                    %% Peeled the EOF frame; drain remaining (defensive).
                    _ = drain_remaining(Stream, ChunkTimeout),
                    {ok, BytesOut2, Frames2};
                {error, _} = Err ->
                    _ = drain_remaining(Stream, ChunkTimeout),
                    Err
            end;
        eof ->
            %% Peer closed without an explicit EOF frame — treat as
            %% truncated if we haven't seen one yet.
            case Buf of
                <<>> -> {error, stream_ended_without_eof_frame};
                _    -> {error, {stream_ended_with_pending_bytes, byte_size(Buf)}}
            end;
        {error, Reason} ->
            {error, {stream_error, Reason}};
        Other ->
            {error, {unexpected_stream_message, Other}}
    end.

peel_and_write(Buf, Fd, BytesOut, Frames) ->
    case hecate_file_frame:decode_frame(Buf) of
        {ok, Envelope, Rest} ->
            Len = byte_size(Envelope),
            Frame = <<Len:32/big, Envelope/binary>>,
            case briefcase_cache_store:write_frame(Fd, Frame) of
                ok ->
                    peel_and_write(Rest, Fd,
                                    BytesOut + byte_size(Frame),
                                    Frames + 1);
                {error, _} = Err ->
                    Err
            end;
        eof ->
            %% Write the EOF marker to the cache too so Phase F's
            %% decrypt loop can detect clean EOF.
            Eof = hecate_file_frame:encode_eof(),
            case briefcase_cache_store:write_frame(Fd, Eof) of
                ok ->
                    {done, BytesOut + byte_size(Eof), Frames};
                {error, _} = Err -> Err
            end;
        {more, _Needed} ->
            {continue, Buf, BytesOut, Frames};
        {error, _} = Err ->
            Err
    end.

%% Best-effort drain of any residual macula messages so the stream
%% gen_server can GC cleanly. Never fails — we've already decided
%% the outcome.
drain_remaining(Stream, Timeout) ->
    case macula:recv(Stream, Timeout) of
        {chunk, _} -> drain_remaining(Stream, Timeout);
        _          -> ok
    end.

finalize(_FileId, {ok, BytesOut, Frames}) ->
    {ok, #{bytes_written => BytesOut, frames => Frames}};
finalize(FileId, {error, _} = Err) ->
    %% Best-effort: remove the partial cache so a retry starts clean.
    _ = briefcase_cache_store:delete(FileId),
    Err.
