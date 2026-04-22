%%% @doc complete_file_download_v1 command.
%%%
%%% Internal command dispatched by `briefcase_download_worker` once
%%% the ciphertext stream has been fully written to
%%% `cache/{XX}/{FileId}.enc`. Emits `file_download_completed_v1`
%%% which flips FILE_CACHED and clears FILE_DOWNLOADING on the
%%% aggregate, and updates the briefcase_files read model to
%%% `presence=cached`.
%%% @end
-module(complete_file_download_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1]).

-record(complete_file_download_v1, {
    file_id      :: binary(),
    source_realm :: binary(),
    cache_size   :: non_neg_integer(),
    frames       :: non_neg_integer(),
    completed_at :: integer()
}).

-opaque complete_file_download_v1() :: #complete_file_download_v1{}.
-export_type([complete_file_download_v1/0]).

command_type() -> complete_file_download_v1.

new(#{file_id := FileId,
      source_realm := Realm,
      cache_size := Size,
      frames := Frames} = P) ->
    At = maps:get(completed_at, P, erlang:system_time(millisecond)),
    {ok, #complete_file_download_v1{
        file_id      = FileId,
        source_realm = Realm,
        cache_size   = Size,
        frames       = Frames,
        completed_at = At}};
new(_) -> {error, missing_fields}.

get_file_id(#complete_file_download_v1{file_id = F}) -> F.

to_map(#complete_file_download_v1{} = C) ->
    #{file_id      => C#complete_file_download_v1.file_id,
      source_realm => C#complete_file_download_v1.source_realm,
      cache_size   => C#complete_file_download_v1.cache_size,
      frames       => C#complete_file_download_v1.frames,
      completed_at => C#complete_file_download_v1.completed_at}.

from_map(Map) -> new(Map).
