%%% @doc share_file_v1 command.
%%%
%%% Flips a local briefcase file from `private` to `shared`. Phase A:
%%% just updates local state (emits `file_shared_v1`). Phase B adds the
%%% mesh FACT emission so peers see the placeholder. Phase D adds
%%% license issuance + CEK wrap.
%%% @end
-module(share_file_v1).
-behaviour(evoq_command).

-export([new/1, new/2, new/3, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1, get_shared_at/1, get_recipients/1]).

-record(share_file_v1, {
    file_id    :: binary(),
    shared_at  :: integer(),
    recipients :: [term()]  %% [realm] | [DID, ...] | [realm | DIDs]
}).

-opaque share_file_v1() :: #share_file_v1{}.
-export_type([share_file_v1/0]).

command_type() -> share_file_v1.

-spec new(map()) -> {ok, share_file_v1()} | {error, missing_fields}.
new(#{file_id := FileId, shared_at := SharedAt} = M) ->
    {ok, new(FileId, SharedAt, maps:get(recipients, M, [realm]))};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), integer()) -> share_file_v1().
new(FileId, SharedAt) ->
    new(FileId, SharedAt, [realm]).

-spec new(binary(), integer(), [term()]) -> share_file_v1().
new(FileId, SharedAt, Recipients) when is_list(Recipients) ->
    #share_file_v1{file_id = FileId, shared_at = SharedAt,
                   recipients = Recipients}.

-spec to_map(share_file_v1()) -> map().
to_map(#share_file_v1{file_id = FileId, shared_at = SharedAt,
                      recipients = Rs}) ->
    #{file_id => FileId, shared_at => SharedAt, recipients => Rs}.

-spec from_map(map()) -> {ok, share_file_v1()} | {error, term()}.
from_map(#{file_id := FileId, shared_at := SharedAt} = M) ->
    {ok, #share_file_v1{file_id = FileId, shared_at = SharedAt,
                        recipients = maps:get(recipients, M, [realm])}};
from_map(_) ->
    {error, invalid_share_file_command}.

get_file_id(#share_file_v1{file_id = V})        -> V.
get_shared_at(#share_file_v1{shared_at = V})    -> V.
get_recipients(#share_file_v1{recipients = V})  -> V.
