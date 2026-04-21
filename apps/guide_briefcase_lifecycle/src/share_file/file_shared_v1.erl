%%% @doc file_shared_v1 domain event.
%%%
%%% Emitted when a local briefcase file transitions from `private` to
%%% `shared`. Distinct from the mesh FACT that an emitter publishes to
%%% `{realm}.briefcase.file_shared` — the FACT is the integration
%%% contract for peers; this event is the internal domain record.
%%%
%%% Carries the file's metadata snapshot at share-time so downstream
%%% consumers (emitter, projection) don't need to re-read the aggregate
%%% or the read model.
%%% @end
-module(file_shared_v1).
-behaviour(evoq_event).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_shared_v1, {
    file_id      :: binary(),
    shared_at    :: integer(),
    realm        :: binary() | undefined,
    path         :: binary() | undefined,
    mime_type    :: binary() | undefined,
    size         :: non_neg_integer() | undefined,
    content_hash :: binary() | undefined,
    author_did   :: binary() | undefined
}).

-opaque file_shared_v1() :: #file_shared_v1{}.
-export_type([file_shared_v1/0]).

event_type() -> <<"file_shared_v1">>.

-spec new(map()) -> file_shared_v1().
new(#{file_id := FileId, shared_at := SharedAt} = M) ->
    #file_shared_v1{
        file_id      = FileId,
        shared_at    = SharedAt,
        realm        = maps:get(realm,        M, undefined),
        path         = maps:get(path,         M, undefined),
        mime_type    = maps:get(mime_type,    M, undefined),
        size         = maps:get(size,         M, undefined),
        content_hash = maps:get(content_hash, M, undefined),
        author_did   = maps:get(author_did,   M, undefined)
    }.

-spec new(binary(), integer()) -> file_shared_v1().
new(FileId, SharedAt) ->
    new(#{file_id => FileId, shared_at => SharedAt}).

-spec to_map(file_shared_v1()) -> map().
to_map(#file_shared_v1{} = E) ->
    #{event_type   => <<"file_shared_v1">>,
      file_id      => E#file_shared_v1.file_id,
      shared_at    => E#file_shared_v1.shared_at,
      realm        => E#file_shared_v1.realm,
      path         => E#file_shared_v1.path,
      mime_type    => E#file_shared_v1.mime_type,
      size         => E#file_shared_v1.size,
      content_hash => E#file_shared_v1.content_hash,
      author_did   => E#file_shared_v1.author_did}.

-spec from_map(map()) -> {ok, file_shared_v1()} | {error, term()}.
from_map(#{file_id := _, shared_at := _} = M) ->
    {ok, new(M)};
from_map(_) ->
    {error, invalid_file_shared_event}.
