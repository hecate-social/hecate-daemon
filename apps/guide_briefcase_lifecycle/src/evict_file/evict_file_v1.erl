%%% @doc evict_file_v1 command.
%%%
%%% Drops a cached `.enc` file from local disk for a remote file we
%%% previously downloaded. Only valid on `FILE_CACHED` rows. Emits
%%% `file_evicted_v1` which clears the flag so the row's presence
%%% flips back to `remote` (placeholder).
%%%
%%% Re-downloading after eviction is a fresh `download_file_v1` call.
%%% @end
-module(evict_file_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1]).

-record(evict_file_v1, {
    file_id :: binary()
}).

-opaque evict_file_v1() :: #evict_file_v1{}.
-export_type([evict_file_v1/0]).

command_type() -> evict_file_v1.

-spec new(map()) -> {ok, evict_file_v1()} | {error, term()}.
new(#{file_id := FileId})
  when is_binary(FileId), byte_size(FileId) > 0 ->
    {ok, #evict_file_v1{file_id = FileId}};
new(_) ->
    {error, missing_fields}.

-spec get_file_id(evict_file_v1()) -> binary().
get_file_id(#evict_file_v1{file_id = F}) -> F.

-spec to_map(evict_file_v1()) -> map().
to_map(#evict_file_v1{file_id = F}) ->
    #{file_id => F}.

-spec from_map(map()) -> {ok, evict_file_v1()} | {error, term()}.
from_map(Map) -> new(Map).
