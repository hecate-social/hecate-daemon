%%% @doc file_cached_v1 domain event.
%%%
%%% Emitted when `download_file_v1` successfully pulls ciphertext from
%%% a peer and persists it to `cache/{XX}/{FileId}.enc`. The projection
%%% flips the row's presence to `cached` and sets `FILE_CACHED` on the
%%% aggregate status so the open-path knows ciphertext is available
%%% locally.
%%%
%%% `cache_size` and `frames` are carried for audit — at replay time
%%% the projection doesn't need them to reconstruct state, but they
%%% surface in APIs (e.g., displaying "235 KB cached, 4 chunks").
%%% @end
-module(file_cached_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_cached_v1, {
    file_id       :: binary(),
    source_realm  :: binary(),
    cache_size    :: non_neg_integer(),
    frames        :: non_neg_integer(),
    cached_at     :: integer()
}).

-opaque file_cached_v1() :: #file_cached_v1{}.
-export_type([file_cached_v1/0]).

event_type() -> <<"file_cached_v1">>.

-spec new(map()) -> {ok, file_cached_v1()} | {error, term()}.
new(#{file_id := FileId,
      source_realm := Realm,
      cache_size := Size,
      frames := Frames} = P) ->
    CachedAt = maps:get(cached_at, P, erlang:system_time(millisecond)),
    {ok, #file_cached_v1{file_id      = FileId,
                         source_realm = Realm,
                         cache_size   = Size,
                         frames       = Frames,
                         cached_at    = CachedAt}};
new(_) ->
    {error, missing_fields}.

-spec to_map(file_cached_v1()) -> map().
to_map(#file_cached_v1{} = E) ->
    #{event_type   => event_type(),
      file_id      => E#file_cached_v1.file_id,
      source_realm => E#file_cached_v1.source_realm,
      cache_size   => E#file_cached_v1.cache_size,
      frames       => E#file_cached_v1.frames,
      cached_at    => E#file_cached_v1.cached_at}.

-spec from_map(map()) -> {ok, file_cached_v1()} | {error, term()}.
from_map(Map) -> new(Map).
