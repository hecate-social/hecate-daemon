%%% @doc RPC handler: <Realm>.briefcase.get_chunk_stream
%%%
%%% Server-stream variant of serve_file_content_rpc:get_chunk. The
%%% legacy unary call returns the whole file in one reply map — fine
%%% for tiny config files, hostile beyond a few MB. This streaming
%%% variant reads the file in fixed-size chunks and emits each as a
%%% raw STREAM_DATA frame, so a 1 GB file moves with stable memory on
%%% both sides.
%%%
%%% Phase 4 pilot consumer of PLAN_MACULA_STREAMING.md.
%%%
%%% Args (open payload):
%%%   #{ <<"file_id">> => binary() }
%%%
%%% Stream chunks: raw bytes (encoding=raw). Each chunk is at most
%%% ?CHUNK_BYTES bytes. EOF on file end. STREAM_ERROR with code
%%% not_available if the file isn't present locally.
-module(stream_file_content_rpc).

-export([procedure/1, handle/2, register/0]).

%% 64 KB matches typical QUIC stream MTU + leaves headroom for relay
%% framing overhead. Same chunk ceiling as the streaming-plan
%% recommendation (PLAN_MACULA_STREAMING.md "frame size cap").
-define(CHUNK_BYTES, 65536).

-spec procedure(binary()) -> binary().
procedure(Realm) when is_binary(Realm) ->
    <<Realm/binary, ".briefcase.get_chunk_stream">>.

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
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    hecate_mesh_client:register_stream_advertisement(
        procedure(Realm),
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
            Path = briefcase_content_store:content_path(FileId),
            stream_path(Stream, Path)
    end.

stream_path(Stream, Path) ->
    case file:open(Path, [read, binary, raw]) of
        {ok, Fd} ->
            Result = pump(Stream, Fd),
            ok = file:close(Fd),
            finalize(Stream, Result);
        {error, Reason} ->
            macula:abort(Stream, <<"open_failed">>,
                         iolist_to_binary(io_lib:format("~p", [Reason]))),
            ok
    end.

pump(Stream, Fd) ->
    case file:read(Fd, ?CHUNK_BYTES) of
        eof -> ok;
        {ok, Chunk} ->
            case macula:send(Stream, Chunk) of
                ok -> pump(Stream, Fd);
                {error, _} = Err -> Err
            end;
        {error, _} = Err -> Err
    end.

finalize(Stream, ok) ->
    macula:close(Stream),
    ok;
finalize(_Stream, {error, _Reason}) ->
    %% macula:send already returned the error — peer is gone or stream
    %% is closed. No further frames to send. The stream gen_server
    %% will be GC'd when its owner exits.
    ok.
