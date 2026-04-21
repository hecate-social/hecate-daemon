%%% @doc file_shared_v1 domain event.
%%%
%%% Emitted when a local briefcase file transitions from `private` to
%%% `shared`. Distinct from the mesh FACT that an emitter publishes to
%%% `{realm}.briefcase.file_shared` — the FACT is the integration
%%% contract for peers; this event is the internal domain record.
%%% @end
-module(file_shared_v1).
-behaviour(evoq_event).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_shared_v1, {
    file_id   :: binary(),
    shared_at :: integer()
}).

-opaque file_shared_v1() :: #file_shared_v1{}.
-export_type([file_shared_v1/0]).

event_type() -> <<"file_shared_v1">>.

-spec new(map()) -> file_shared_v1().
new(#{file_id := FileId, shared_at := SharedAt}) ->
    new(FileId, SharedAt).

-spec new(binary(), integer()) -> file_shared_v1().
new(FileId, SharedAt) ->
    #file_shared_v1{file_id = FileId, shared_at = SharedAt}.

-spec to_map(file_shared_v1()) -> map().
to_map(#file_shared_v1{file_id = FileId, shared_at = SharedAt}) ->
    #{event_type => <<"file_shared_v1">>,
      file_id    => FileId,
      shared_at  => SharedAt}.

-spec from_map(map()) -> {ok, file_shared_v1()} | {error, term()}.
from_map(#{file_id := FileId, shared_at := SharedAt}) ->
    {ok, #file_shared_v1{file_id = FileId, shared_at = SharedAt}};
from_map(_) ->
    {error, invalid_file_shared_event}.
