%%% @doc file_download_completed_v1 domain event.
%%%
%%% Terminal-success event of the async download flow. Replaces the
%%% Phase E-initial `file_cached_v1` — that old event type is kept in
%%% the state/projection fold via upcaster so previously-persisted
%%% streams replay unchanged, but new code emits only this name.
%%%
%%% Semantically identical to file_cached_v1 plus the additional
%%% invariant that it MUST follow a file_download_started_v1 on the
%%% same aggregate.
%%% @end
-module(file_download_completed_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_download_completed_v1, {
    file_id      :: binary(),
    source_realm :: binary(),
    cache_size   :: non_neg_integer(),
    frames       :: non_neg_integer(),
    completed_at :: integer()
}).

-opaque file_download_completed_v1() :: #file_download_completed_v1{}.
-export_type([file_download_completed_v1/0]).

event_type() -> <<"file_download_completed_v1">>.

new(#{file_id := FileId,
      source_realm := Realm,
      cache_size := Size,
      frames := Frames} = P) ->
    At = maps:get(completed_at, P, erlang:system_time(millisecond)),
    {ok, #file_download_completed_v1{
        file_id      = FileId,
        source_realm = Realm,
        cache_size   = Size,
        frames       = Frames,
        completed_at = At}};
new(_) -> {error, missing_fields}.

to_map(#file_download_completed_v1{} = E) ->
    #{event_type   => event_type(),
      file_id      => E#file_download_completed_v1.file_id,
      source_realm => E#file_download_completed_v1.source_realm,
      cache_size   => E#file_download_completed_v1.cache_size,
      frames       => E#file_download_completed_v1.frames,
      completed_at => E#file_download_completed_v1.completed_at}.

from_map(Map) -> new(Map).
