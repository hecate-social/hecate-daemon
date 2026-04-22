%%% @doc download_file_v1 command.
%%%
%%% Pulls a file announced by a peer: calls
%%% `<realm>.briefcase.get_chunk_stream`, writes received ciphertext
%%% frames to `cache/{XX}/{FileId}.enc`, emits `file_cached_v1`.
%%%
%%% Only valid on a remote file that has been `file_announced_v1`'d
%%% and not yet cached. The aggregate enforces this gate.
%%% @end
-module(download_file_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1]).

-record(download_file_v1, {
    file_id :: binary()
}).

-opaque download_file_v1() :: #download_file_v1{}.
-export_type([download_file_v1/0]).

command_type() -> download_file_v1.

-spec new(map()) -> {ok, download_file_v1()} | {error, term()}.
new(#{file_id := FileId})
  when is_binary(FileId), byte_size(FileId) > 0 ->
    {ok, #download_file_v1{file_id = FileId}};
new(_) ->
    {error, missing_fields}.

-spec get_file_id(download_file_v1()) -> binary().
get_file_id(#download_file_v1{file_id = F}) -> F.

-spec to_map(download_file_v1()) -> map().
to_map(#download_file_v1{file_id = F}) ->
    #{file_id => F}.

-spec from_map(map()) -> {ok, download_file_v1()} | {error, term()}.
from_map(Map) -> new(Map).
