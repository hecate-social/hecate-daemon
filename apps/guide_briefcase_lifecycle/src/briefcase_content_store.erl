%%% @doc On-disk content store for Briefcase files.
%%%
%%% Phase 1: whole-file storage, content-addressed. Each file lives at:
%%%     $HECATE_HOME/hecate-daemon/briefcase/content/{XX}/{FileId}.bin
%%% where `XX` is the first 2 hex chars of the file_id (BLAKE3 hash) —
%%% load-spreading over 256 sub-directories.
%%%
%%% Phase 3 replaces this with chunked storage:
%%%     .../chunks/{XX}/{ChunkHash}.enc
%%% and files become ordered sequences of chunk hashes.
%%% @end
-module(briefcase_content_store).

-export([put/2, get/1, delete/1, exists/1]).
-export([content_dir/0, content_path/1]).

%% @doc Root directory for content storage.
-spec content_dir() -> file:filename().
content_dir() ->
    Dir = filename:join(shared_paths:base_dir(), "briefcase/content"),
    ok = filelib:ensure_path(Dir),
    Dir.

%% @doc Absolute on-disk path for a given file_id.
-spec content_path(binary()) -> file:filename().
content_path(FileId) when is_binary(FileId), byte_size(FileId) >= 2 ->
    Prefix = binary:part(FileId, 0, 2),
    SubDir = filename:join(content_dir(), binary_to_list(Prefix)),
    ok = filelib:ensure_path(SubDir),
    Name = <<FileId/binary, ".bin">>,
    filename:join(SubDir, binary_to_list(Name)).

%% @doc Write content bytes. Idempotent — same FileId overwrites.
-spec put(binary(), binary()) -> ok | {error, term()}.
put(FileId, Content) when is_binary(FileId), is_binary(Content) ->
    Path = content_path(FileId),
    file:write_file(Path, Content).

%% @doc Read content bytes.
-spec get(binary()) -> {ok, binary()} | {error, term()}.
get(FileId) when is_binary(FileId) ->
    Path = content_path(FileId),
    file:read_file(Path).

%% @doc Remove a file's content.
-spec delete(binary()) -> ok | {error, term()}.
delete(FileId) when is_binary(FileId) ->
    Path = content_path(FileId),
    case file:delete(Path) of
        ok -> ok;
        {error, enoent} -> ok;
        {error, _} = E -> E
    end.

%% @doc Check if content is present locally.
-spec exists(binary()) -> boolean().
exists(FileId) when is_binary(FileId) ->
    filelib:is_regular(content_path(FileId)).
