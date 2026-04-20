%%% @doc file_uploaded_v1 event.
%%%
%%% Emitted on first appearance of a file in the briefcase.
%%% Subsequent modifications emit `file_revised_v{N}` (future phase).
%%% @end
-module(file_uploaded_v1).
-behaviour(evoq_event).

-export([new/1, new/8, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_uploaded_v1, {
    file_id      :: binary(),
    realm        :: binary(),
    path         :: binary(),
    mime_type    :: binary(),
    size         :: non_neg_integer(),
    content_hash :: binary(),
    author_did   :: binary(),
    uploaded_at  :: integer()
}).

-opaque file_uploaded_v1() :: #file_uploaded_v1{}.
-export_type([file_uploaded_v1/0]).

event_type() -> <<"file_uploaded_v1">>.

-spec new(map()) -> file_uploaded_v1().
new(#{file_id := FileId, realm := Realm, path := Path,
      mime_type := Mime, size := Size, content_hash := Hash,
      author_did := Did, uploaded_at := UploadedAt}) ->
    new(FileId, Realm, Path, Mime, Size, Hash, Did, UploadedAt).

-spec new(binary(), binary(), binary(), binary(), non_neg_integer(),
          binary(), binary(), integer()) -> file_uploaded_v1().
new(FileId, Realm, Path, Mime, Size, Hash, Did, UploadedAt) ->
    #file_uploaded_v1{
        file_id      = FileId,
        realm        = Realm,
        path         = Path,
        mime_type    = Mime,
        size         = Size,
        content_hash = Hash,
        author_did   = Did,
        uploaded_at  = UploadedAt
    }.

-spec to_map(file_uploaded_v1()) -> map().
to_map(#file_uploaded_v1{
    file_id = FileId, realm = Realm, path = Path, mime_type = Mime,
    size = Size, content_hash = Hash, author_did = Did,
    uploaded_at = UploadedAt}) ->
    #{
        event_type   => <<"file_uploaded_v1">>,
        file_id      => FileId,
        realm        => Realm,
        path         => Path,
        mime_type    => Mime,
        size         => Size,
        content_hash => Hash,
        author_did   => Did,
        uploaded_at  => UploadedAt
    }.

-spec from_map(map()) -> {ok, file_uploaded_v1()} | {error, term()}.
from_map(#{file_id := FileId, realm := Realm, path := Path,
           mime_type := Mime, size := Size, content_hash := Hash,
           author_did := Did, uploaded_at := UploadedAt}) ->
    {ok, #file_uploaded_v1{
        file_id = FileId, realm = Realm, path = Path, mime_type = Mime,
        size = Size, content_hash = Hash, author_did = Did,
        uploaded_at = UploadedAt
    }};
from_map(_) ->
    {error, invalid_file_uploaded_event}.
