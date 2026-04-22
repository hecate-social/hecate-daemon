%%% @doc file_evicted_v1 domain event.
%%%
%%% Emitted after a successful `briefcase_cache_store:delete/1`
%%% cleared the ciphertext from disk. The projection unsets the row's
%%% cached presence so the UI shows the placeholder again.
%%% @end
-module(file_evicted_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_evicted_v1, {
    file_id    :: binary(),
    evicted_at :: integer()
}).

-opaque file_evicted_v1() :: #file_evicted_v1{}.
-export_type([file_evicted_v1/0]).

event_type() -> <<"file_evicted_v1">>.

-spec new(map()) -> {ok, file_evicted_v1()} | {error, term()}.
new(#{file_id := FileId} = P) ->
    EvictedAt = maps:get(evicted_at, P, erlang:system_time(millisecond)),
    {ok, #file_evicted_v1{file_id = FileId, evicted_at = EvictedAt}};
new(_) ->
    {error, missing_fields}.

-spec to_map(file_evicted_v1()) -> map().
to_map(#file_evicted_v1{file_id = F, evicted_at = At}) ->
    #{event_type => event_type(),
      file_id    => F,
      evicted_at => At}.

-spec from_map(map()) -> {ok, file_evicted_v1()} | {error, term()}.
from_map(Map) -> new(Map).
