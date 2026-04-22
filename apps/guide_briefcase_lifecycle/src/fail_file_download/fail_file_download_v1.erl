%%% @doc fail_file_download_v1 command.
%%%
%%% Internal command dispatched by `briefcase_download_worker` on any
%%% non-recoverable fetch error (peer offline, CEK unseal failure,
%%% tag mismatch on a frame, disk write error, partial stream).
%%% Emits `file_download_failed_v1` which clears FILE_DOWNLOADING —
%%% the aggregate returns to FILE_ANNOUNCED, ready for retry.
%%% @end
-module(fail_file_download_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_file_id/1]).

-record(fail_file_download_v1, {
    file_id       :: binary(),
    reason        :: term(),
    partial_bytes :: non_neg_integer(),
    failed_at     :: integer()
}).

-opaque fail_file_download_v1() :: #fail_file_download_v1{}.
-export_type([fail_file_download_v1/0]).

command_type() -> fail_file_download_v1.

new(#{file_id := FileId} = P) ->
    At = maps:get(failed_at, P, erlang:system_time(millisecond)),
    {ok, #fail_file_download_v1{
        file_id       = FileId,
        reason        = maps:get(reason, P, unknown),
        partial_bytes = maps:get(partial_bytes, P, 0),
        failed_at     = At}};
new(_) -> {error, missing_fields}.

get_file_id(#fail_file_download_v1{file_id = F}) -> F.

to_map(#fail_file_download_v1{} = C) ->
    #{file_id       => C#fail_file_download_v1.file_id,
      reason        => C#fail_file_download_v1.reason,
      partial_bytes => C#fail_file_download_v1.partial_bytes,
      failed_at     => C#fail_file_download_v1.failed_at}.

from_map(Map) -> new(Map).
