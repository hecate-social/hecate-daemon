%%% @doc file_download_failed_v1 domain event.
%%%
%%% Terminal-failure event of the async download flow. Clears the
%%% FILE_DOWNLOADING bit so a retry (new start_file_download_v1) is
%%% accepted. Carries the reason + partial bytes for audit + UI
%%% surfacing.
%%% @end
-module(file_download_failed_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_download_failed_v1, {
    file_id       :: binary(),
    reason        :: term(),
    partial_bytes :: non_neg_integer(),
    failed_at     :: integer()
}).

-opaque file_download_failed_v1() :: #file_download_failed_v1{}.
-export_type([file_download_failed_v1/0]).

event_type() -> <<"file_download_failed_v1">>.

new(#{file_id := FileId} = P) ->
    At = maps:get(failed_at, P, erlang:system_time(millisecond)),
    {ok, #file_download_failed_v1{
        file_id       = FileId,
        reason        = maps:get(reason, P, unknown),
        partial_bytes = maps:get(partial_bytes, P, 0),
        failed_at     = At}};
new(_) -> {error, missing_fields}.

to_map(#file_download_failed_v1{} = E) ->
    #{event_type    => event_type(),
      file_id       => E#file_download_failed_v1.file_id,
      reason        => format_reason(E#file_download_failed_v1.reason),
      partial_bytes => E#file_download_failed_v1.partial_bytes,
      failed_at     => E#file_download_failed_v1.failed_at}.

from_map(Map) -> new(Map).

%% @private Normalise error terms for the event payload. Arbitrary
%% erlang terms aren't JSON-friendly; convert tuples/atoms to
%% binaries so the mesh emitter (if we ever add one) can encode the
%% event, and the API handler can surface a readable message.
format_reason(A) when is_atom(A) -> A;
format_reason(B) when is_binary(B) -> B;
format_reason(Other) ->
    iolist_to_binary(io_lib:format("~p", [Other])).
