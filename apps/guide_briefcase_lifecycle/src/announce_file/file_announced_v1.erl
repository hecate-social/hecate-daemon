%%% @doc file_announced_v1 domain event.
%%%
%%% Local record that a peer in our realm published a
%%% `io.macula.briefcase.file_shared` FACT. Creates a `remote +
%%% placeholder` row in the briefcase read model. Content is NOT
%%% fetched here — that's the `file_cached_v1` transition (Phase E).
%%% @end
-module(file_announced_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_announced_v1, {
    file_id      :: binary(),
    realm        :: binary(),
    path         :: binary(),
    mime_type    :: binary() | undefined,
    size         :: non_neg_integer() | undefined,
    content_hash :: binary() | undefined,
    author_did   :: binary() | undefined,
    announced_at :: integer()
}).

-opaque file_announced_v1() :: #file_announced_v1{}.
-export_type([file_announced_v1/0]).

event_type() -> <<"file_announced_v1">>.

-spec new(map()) -> file_announced_v1().
new(#{file_id := FileId, realm := Realm, path := Path} = M) ->
    #file_announced_v1{
        file_id      = FileId,
        realm        = Realm,
        path         = Path,
        mime_type    = maps:get(mime_type,    M, undefined),
        size         = maps:get(size,         M, undefined),
        content_hash = maps:get(content_hash, M, undefined),
        author_did   = maps:get(author_did,   M, undefined),
        announced_at = maps:get(announced_at, M, erlang:system_time(millisecond))
    }.

-spec to_map(file_announced_v1()) -> map().
to_map(#file_announced_v1{} = E) ->
    #{event_type   => <<"file_announced_v1">>,
      file_id      => E#file_announced_v1.file_id,
      realm        => E#file_announced_v1.realm,
      path         => E#file_announced_v1.path,
      mime_type    => E#file_announced_v1.mime_type,
      size         => E#file_announced_v1.size,
      content_hash => E#file_announced_v1.content_hash,
      author_did   => E#file_announced_v1.author_did,
      announced_at => E#file_announced_v1.announced_at}.

-spec from_map(map()) -> {ok, file_announced_v1()} | {error, term()}.
from_map(#{file_id := _, realm := _, path := _} = M) ->
    {ok, new(M)};
from_map(_) ->
    {error, invalid_file_announced_event}.
