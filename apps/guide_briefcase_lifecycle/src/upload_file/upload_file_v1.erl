%%% @doc upload_file_v1 command.
%%%
%%% First appearance of a file in the briefcase. Subsequent modifications
%%% use `revise_file_v{N}` (not in Phase 1 scaffold).
%%% @end
-module(upload_file_v1).
-behaviour(evoq_command).

-export([new/1, new/8, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_realm/1, get_path/1, get_mime_type/1,
         get_size/1, get_content_hash/1, get_author_did/1, get_uploaded_at/1]).

-record(upload_file_v1, {
    file_id      :: binary(),
    realm        :: binary(),
    path         :: binary(),
    mime_type    :: binary(),
    size         :: non_neg_integer(),
    content_hash :: binary(),
    author_did   :: binary(),
    uploaded_at  :: integer()
}).

-opaque upload_file_v1() :: #upload_file_v1{}.
-export_type([upload_file_v1/0]).

command_type() -> upload_file_v1.

-spec new(map()) -> {ok, upload_file_v1()} | {error, missing_fields}.
new(#{file_id := FileId, realm := Realm, path := Path,
      mime_type := Mime, size := Size, content_hash := Hash,
      author_did := Did, uploaded_at := UploadedAt}) ->
    {ok, new(FileId, Realm, Path, Mime, Size, Hash, Did, UploadedAt)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary(), binary(), binary(), non_neg_integer(),
          binary(), binary(), integer()) -> upload_file_v1().
new(FileId, Realm, Path, Mime, Size, Hash, Did, UploadedAt) ->
    #upload_file_v1{
        file_id      = FileId,
        realm        = Realm,
        path         = Path,
        mime_type    = Mime,
        size         = Size,
        content_hash = Hash,
        author_did   = Did,
        uploaded_at  = UploadedAt
    }.

-spec to_map(upload_file_v1()) -> map().
to_map(#upload_file_v1{
    file_id = FileId, realm = Realm, path = Path, mime_type = Mime,
    size = Size, content_hash = Hash, author_did = Did,
    uploaded_at = UploadedAt}) ->
    #{
        file_id      => FileId,
        realm        => Realm,
        path         => Path,
        mime_type    => Mime,
        size         => Size,
        content_hash => Hash,
        author_did   => Did,
        uploaded_at  => UploadedAt
    }.

-spec from_map(map()) -> {ok, upload_file_v1()} | {error, term()}.
from_map(#{file_id := FileId, realm := Realm, path := Path,
           mime_type := Mime, size := Size, content_hash := Hash,
           author_did := Did, uploaded_at := UploadedAt}) ->
    {ok, #upload_file_v1{
        file_id = FileId, realm = Realm, path = Path, mime_type = Mime,
        size = Size, content_hash = Hash, author_did = Did,
        uploaded_at = UploadedAt
    }};
from_map(_) ->
    {error, invalid_upload_file_command}.

get_file_id(#upload_file_v1{file_id = V}) -> V.
get_realm(#upload_file_v1{realm = V}) -> V.
get_path(#upload_file_v1{path = V}) -> V.
get_mime_type(#upload_file_v1{mime_type = V}) -> V.
get_size(#upload_file_v1{size = V}) -> V.
get_content_hash(#upload_file_v1{content_hash = V}) -> V.
get_author_did(#upload_file_v1{author_did = V}) -> V.
get_uploaded_at(#upload_file_v1{uploaded_at = V}) -> V.
