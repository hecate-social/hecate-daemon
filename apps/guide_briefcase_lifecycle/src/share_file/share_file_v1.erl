%%% @doc share_file_v1 command.
%%%
%%% Flips a local briefcase file from `private` to `shared`. Phase A:
%%% just updates local state (emits `file_shared_v1`). Phase B adds the
%%% mesh FACT emission so peers see the placeholder. Phase D adds
%%% license issuance + CEK wrap.
%%% @end
-module(share_file_v1).
-behaviour(evoq_command).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_shared_at/1]).

-record(share_file_v1, {
    file_id   :: binary(),
    shared_at :: integer()
}).

-opaque share_file_v1() :: #share_file_v1{}.
-export_type([share_file_v1/0]).

command_type() -> share_file_v1.

-spec new(map()) -> {ok, share_file_v1()} | {error, missing_fields}.
new(#{file_id := FileId, shared_at := SharedAt}) ->
    {ok, new(FileId, SharedAt)};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), integer()) -> share_file_v1().
new(FileId, SharedAt) ->
    #share_file_v1{file_id = FileId, shared_at = SharedAt}.

-spec to_map(share_file_v1()) -> map().
to_map(#share_file_v1{file_id = FileId, shared_at = SharedAt}) ->
    #{file_id => FileId, shared_at => SharedAt}.

-spec from_map(map()) -> {ok, share_file_v1()} | {error, term()}.
from_map(#{file_id := FileId, shared_at := SharedAt}) ->
    {ok, #share_file_v1{file_id = FileId, shared_at = SharedAt}};
from_map(_) ->
    {error, invalid_share_file_command}.

get_file_id(#share_file_v1{file_id = V}) -> V.
get_shared_at(#share_file_v1{shared_at = V}) -> V.
