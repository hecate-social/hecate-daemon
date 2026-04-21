%%% @doc file_unshared_v1 domain event.
%%%
%%% Emitted when a local briefcase file transitions from `shared` back
%%% to `private`. Distinct from mesh FACT retraction that an emitter
%%% publishes in Phase B.
%%% @end
-module(file_unshared_v1).
-behaviour(evoq_event).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_unshared_v1, {
    file_id     :: binary(),
    unshared_at :: integer()
}).

-opaque file_unshared_v1() :: #file_unshared_v1{}.
-export_type([file_unshared_v1/0]).

event_type() -> <<"file_unshared_v1">>.

-spec new(map()) -> file_unshared_v1().
new(#{file_id := FileId, unshared_at := UnsharedAt}) ->
    new(FileId, UnsharedAt).

-spec new(binary(), integer()) -> file_unshared_v1().
new(FileId, UnsharedAt) ->
    #file_unshared_v1{file_id = FileId, unshared_at = UnsharedAt}.

-spec to_map(file_unshared_v1()) -> map().
to_map(#file_unshared_v1{file_id = FileId, unshared_at = UnsharedAt}) ->
    #{event_type  => <<"file_unshared_v1">>,
      file_id     => FileId,
      unshared_at => UnsharedAt}.

-spec from_map(map()) -> {ok, file_unshared_v1()} | {error, term()}.
from_map(#{file_id := FileId, unshared_at := UnsharedAt}) ->
    {ok, #file_unshared_v1{file_id = FileId, unshared_at = UnsharedAt}};
from_map(_) ->
    {error, invalid_file_unshared_event}.
