%%% @doc Ciphertext cache for files fetched from peers.
%%%
%%% Parallel to `briefcase_content_store` — that module holds the
%%% OWNER's plaintext uploads; this module holds CIPHERTEXT that a
%%% RECIPIENT pulled from a peer. On-disk layout:
%%%
%%%     $HECATE_HOME/hecate-daemon/briefcase/cache/{XX}/{FileId}.enc
%%%
%%% The `.enc` contents are a sequence of `hecate_file_frame` frames
%%% (length-prefixed AES-256-GCM envelopes) terminated by an EOF
%%% frame. The recipient's `accepted_license_aggregate` holds the
%%% sealed CEK needed to decrypt; Phase F decrypts chunk-by-chunk at
%%% open time.
%%%
%%% Plaintext never touches disk on the recipient side — that's the
%%% privacy guarantee of PLAN_BRIEFCASE_PRESENCE_PRIVACY.md.
%%% @end
-module(briefcase_cache_store).

-include_lib("kernel/include/file.hrl").

-export([cache_dir/0, cache_path/1]).
-export([exists/1, size/1, delete/1]).
-export([open_writer/1, write_frame/2, close_writer/1]).
-export([open_reader/1, read_exact/2, close_reader/1]).

-type writer() :: file:io_device().
-type reader() :: file:io_device().

%%====================================================================
%% Layout
%%====================================================================

-spec cache_dir() -> file:filename().
cache_dir() ->
    Dir = filename:join(shared_paths:base_dir(), "briefcase/cache"),
    ok = filelib:ensure_path(Dir),
    Dir.

-spec cache_path(binary()) -> file:filename().
cache_path(FileId) when is_binary(FileId), byte_size(FileId) >= 2 ->
    Prefix = binary:part(FileId, 0, 2),
    SubDir = filename:join(cache_dir(), binary_to_list(Prefix)),
    ok = filelib:ensure_path(SubDir),
    Name = <<FileId/binary, ".enc">>,
    filename:join(SubDir, binary_to_list(Name)).

%%====================================================================
%% Lifecycle
%%====================================================================

-spec exists(binary()) -> boolean().
exists(FileId) when is_binary(FileId) ->
    filelib:is_regular(cache_path(FileId)).

-spec size(binary()) -> {ok, non_neg_integer()} | {error, term()}.
size(FileId) when is_binary(FileId) ->
    case file:read_file_info(cache_path(FileId)) of
        {ok, #file_info{size = Size}} -> {ok, Size};
        {error, _} = Err              -> Err
    end.

-spec delete(binary()) -> ok | {error, term()}.
delete(FileId) when is_binary(FileId) ->
    case file:delete(cache_path(FileId)) of
        ok              -> ok;
        {error, enoent} -> ok;
        {error, _} = E  -> E
    end.

%%====================================================================
%% Writer (streaming-in)
%%====================================================================

%% @doc Open `cache_path(FileId)` for raw binary writes. Truncates
%% any existing file so a repeat download doesn't leave half-old
%% ciphertext. Callers pair this with `write_frame/2` calls and a
%% final `close_writer/1` when the EOF frame has been written.
-spec open_writer(binary()) -> {ok, writer()} | {error, term()}.
open_writer(FileId) ->
    file:open(cache_path(FileId),
              [write, binary, raw, delayed_write]).

%% @doc Write a prepared frame (already length-prefixed + encrypted)
%% to the writer. Callers should use `hecate_file_frame:encode_*` to
%% build the frame, then hand it here.
-spec write_frame(writer(), binary()) -> ok | {error, term()}.
write_frame(Fd, Frame) when is_binary(Frame) ->
    file:write(Fd, Frame).

-spec close_writer(writer()) -> ok | {error, term()}.
close_writer(Fd) ->
    file:close(Fd).

%%====================================================================
%% Reader (streaming-out for Phase F decrypt)
%%====================================================================

-spec open_reader(binary()) -> {ok, reader()} | {error, term()}.
open_reader(FileId) ->
    file:open(cache_path(FileId), [read, binary, raw, read_ahead]).

%% @doc Read exactly `N` bytes or return `eof` / error. Phase F's
%% decrypt loop reads 4 bytes for the length prefix, then N bytes for
%% the envelope, so it needs precise reads rather than "up to N".
-spec read_exact(reader(), pos_integer()) ->
    {ok, binary()} | eof | {error, term()}.
read_exact(Fd, N) ->
    case file:read(Fd, N) of
        {ok, Bin} when byte_size(Bin) == N -> {ok, Bin};
        {ok, _Short} -> {error, truncated};
        eof          -> eof;
        {error, _} = Err -> Err
    end.

-spec close_reader(reader()) -> ok | {error, term()}.
close_reader(Fd) ->
    file:close(Fd).

