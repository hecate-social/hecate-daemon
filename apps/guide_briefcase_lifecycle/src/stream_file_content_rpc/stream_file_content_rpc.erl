%%% @doc RPC handler: <Realm>.briefcase.get_chunk_stream
%%%
%%% Server-stream variant of serve_file_content_rpc:get_chunk. The
%%% legacy unary call returns the whole file in one reply map — fine
%%% for tiny config files, hostile beyond a few MB. This streaming
%%% variant reads the file in fixed-size plaintext chunks, AES-256-GCM
%%% encrypts each with the per-file CEK, and emits the resulting
%%% framed envelopes as STREAM_DATA frames. A 1 GB file moves with
%%% stable memory on both sides AND ciphertext is all that crosses
%%% the wire — the serving daemon's CEK plaintext never leaves
%%% process memory.
%%%
%%% Phase 4 pilot consumer of PLAN_MACULA_STREAMING.md + Phase E
%%% encrypt-on-serve (PLAN_BRIEFCASE_PRESENCE_PRIVACY.md).
%%%
%%% Args (open payload):
%%%   #{ <<"file_id">> => binary() }
%%%
%%% Stream format: `hecate_file_frame` frames — each frame is
%%% `u32 length | nonce:12 | tag:16 | ciphertext`. EOF is an explicit
%%% zero-length frame. STREAM_ERROR with code `not_available` if the
%%% file isn't present locally, `no_cek` if the per-file CEK isn't in
%%% the `my_issued_files` index (file was never licensed by this
%%% daemon).
-module(stream_file_content_rpc).

-export([procedure/0, handle/2, register/0]).

%% 64 KB plaintext per chunk. Envelope adds 12 + 16 = 28 bytes nonce
%% + tag, so wire chunk is at most 65564 bytes plus the 4-byte length
%% prefix. Matches the PLAN_MACULA_STREAMING.md frame-size cap.
-define(CHUNK_BYTES, 65536).

-spec procedure() -> binary().
procedure() ->
    hecate_topics:app_hope(<<"briefcase">>, <<"get_chunk_stream">>, 1).

%% @doc Stream handler. Reads the file from briefcase_content_store
%% and emits raw chunks until EOF. Aborts with STREAM_ERROR on missing
%% file or read failure.
-spec handle(pid(), term()) -> ok.
handle(Stream, Args) ->
    case parse_file_id(Args) of
        {ok, FileId} ->
            stream_file(Stream, FileId);
        {error, Reason} ->
            macula:abort(Stream, <<"bad_request">>, Reason),
            ok
    end.

%% @doc Register the streaming advertisement. Safe to call at boot —
%% queued until the mesh activates.
-spec register() -> ok.
register() ->
    hecate_mesh_client:register_stream_advertisement(
        procedure(),
        server_stream,
        fun ?MODULE:handle/2).

%%%-------------------------------------------------------------------
%%% Internals
%%%-------------------------------------------------------------------

parse_file_id(#{<<"file_id">> := FileId}) when is_binary(FileId), byte_size(FileId) > 0 ->
    {ok, FileId};
parse_file_id(#{file_id := FileId}) when is_binary(FileId), byte_size(FileId) > 0 ->
    {ok, FileId};
parse_file_id(_) ->
    {error, <<"missing file_id">>}.

stream_file(Stream, FileId) ->
    case briefcase_content_store:exists(FileId) of
        false ->
            macula:abort(Stream, <<"not_available">>, <<"file not present">>),
            ok;
        true ->
            with_cek(Stream, FileId, fun(Cek) ->
                Path = briefcase_content_store:content_path(FileId),
                stream_path(Stream, Path, Cek)
            end)
    end.

%% @private Look up + unseal the per-file CEK; abort the stream with
%% an informative error code if unavailable. Plaintext CEK lives only
%% inside `Fn`'s scope and never escapes this module.
with_cek(Stream, FileId, Fn) ->
    case hecate_file_cek:sealed(FileId) of
        {ok, Sealed} ->
            case hecate_file_cek:unseal(Sealed) of
                {ok, Cek} ->
                    Fn(Cek);
                {error, Reason} ->
                    macula:abort(Stream, <<"cek_unseal_failed">>,
                                 iolist_to_binary(io_lib:format("~p", [Reason]))),
                    ok
            end;
        {error, not_found} ->
            macula:abort(Stream, <<"no_cek">>,
                         <<"file has no issued CEK on this daemon">>),
            ok
    end.

stream_path(Stream, Path, Cek) ->
    case file:open(Path, [read, binary, raw]) of
        {ok, Fd} ->
            Result = pump(Stream, Fd, Cek),
            ok = file:close(Fd),
            finalize(Stream, Result);
        {error, Reason} ->
            macula:abort(Stream, <<"open_failed">>,
                         iolist_to_binary(io_lib:format("~p", [Reason]))),
            ok
    end.

pump(Stream, Fd, Cek) ->
    case file:read(Fd, ?CHUNK_BYTES) of
        eof -> ok;
        {ok, Chunk} ->
            Frame = hecate_file_frame:encode_chunk(Cek, Chunk),
            case macula:send(Stream, Frame) of
                ok -> pump(Stream, Fd, Cek);
                {error, _} = Err -> Err
            end;
        {error, _} = Err -> Err
    end.

finalize(Stream, ok) ->
    %% Emit explicit EOF frame before closing so peers can distinguish
    %% clean end-of-stream from a truncated transfer.
    _ = macula:send(Stream, hecate_file_frame:encode_eof()),
    macula:close(Stream),
    ok;
finalize(_Stream, {error, _Reason}) ->
    %% macula:send already returned the error — peer is gone or stream
    %% is closed. No further frames to send. The stream gen_server
    %% will be GC'd when its owner exits.
    ok.
