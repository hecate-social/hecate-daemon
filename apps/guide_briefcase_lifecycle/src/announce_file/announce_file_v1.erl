%%% @doc announce_file_v1 command.
%%%
%%% Issued by `listen_for_shared_files` when a peer's
%%% `io.macula.briefcase.file_shared` FACT arrives. Carries the full
%%% metadata from the FACT so the aggregate can record a remote-origin
%%% birth without having to re-hit the mesh.
%%% @end
-module(announce_file_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0, get_file_id/1]).

-record(announce_file_v1, {
    file_id      :: binary(),
    realm        :: binary(),
    path         :: binary(),
    mime_type    :: binary() | undefined,
    size         :: non_neg_integer() | undefined,
    content_hash :: binary() | undefined,
    author_did   :: binary() | undefined,
    announced_at :: integer()
}).

-opaque announce_file_v1() :: #announce_file_v1{}.
-export_type([announce_file_v1/0]).

command_type() -> announce_file_v1.

get_file_id(#announce_file_v1{file_id = FileId}) -> FileId.

-spec new(map()) -> announce_file_v1().
new(#{file_id := FileId, realm := Realm, path := Path} = M) ->
    #announce_file_v1{
        file_id      = FileId,
        realm        = Realm,
        path         = Path,
        mime_type    = maps:get(mime_type,    M, undefined),
        size         = maps:get(size,         M, undefined),
        content_hash = maps:get(content_hash, M, undefined),
        author_did   = maps:get(author_did,   M, undefined),
        announced_at = maps:get(announced_at, M, erlang:system_time(millisecond))
    }.

-spec to_map(announce_file_v1()) -> map().
to_map(#announce_file_v1{} = C) ->
    #{command_type => announce_file_v1,
      file_id      => C#announce_file_v1.file_id,
      realm        => C#announce_file_v1.realm,
      path         => C#announce_file_v1.path,
      mime_type    => C#announce_file_v1.mime_type,
      size         => C#announce_file_v1.size,
      content_hash => C#announce_file_v1.content_hash,
      author_did   => C#announce_file_v1.author_did,
      announced_at => C#announce_file_v1.announced_at}.

-spec from_map(map()) -> {ok, announce_file_v1()} | {error, term()}.
from_map(#{file_id := _, realm := _, path := _} = M) ->
    {ok, new(M)};
from_map(_) ->
    {error, invalid_announce_file_command}.
