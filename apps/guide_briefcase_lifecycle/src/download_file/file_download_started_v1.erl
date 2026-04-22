%%% @doc file_download_started_v1 domain event.
%%%
%%% Emitted by `maybe_download_file` when the user initiates a pull
%%% for a remote-announced file. Carries the realm + issuer hints the
%%% worker needs to call the right streaming RPC. Importantly emitted
%%% BEFORE any network I/O — so an evoq event handler
%%% (`on_file_download_started_fetch_bytes`) can spawn a supervised
%%% worker that pumps the stream asynchronously, leaving the cowboy
%%% worker that dispatched the command free to return 202.
%%%
%%% Flips the aggregate's FILE_DOWNLOADING bit. Cleared on a
%%% `file_download_completed_v1` (success → also sets FILE_CACHED),
%%% `file_download_failed_v1` (error, bit clears, cache stays gone),
%%% or `file_download_cancelled_v1` (user aborted).
%%% @end
-module(file_download_started_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(file_download_started_v1, {
    file_id      :: binary(),
    realm        :: binary(),
    issuer_did   :: binary() | undefined,
    started_at   :: integer()
}).

-opaque file_download_started_v1() :: #file_download_started_v1{}.
-export_type([file_download_started_v1/0]).

event_type() -> <<"file_download_started_v1">>.

-spec new(map()) -> {ok, file_download_started_v1()} | {error, term()}.
new(#{file_id := FileId, realm := Realm} = P) ->
    StartedAt = maps:get(started_at, P, erlang:system_time(millisecond)),
    {ok, #file_download_started_v1{
        file_id    = FileId,
        realm      = Realm,
        issuer_did = maps:get(issuer_did, P, undefined),
        started_at = StartedAt}};
new(_) ->
    {error, missing_fields}.

-spec to_map(file_download_started_v1()) -> map().
to_map(#file_download_started_v1{} = E) ->
    #{event_type => event_type(),
      file_id    => E#file_download_started_v1.file_id,
      realm      => E#file_download_started_v1.realm,
      issuer_did => E#file_download_started_v1.issuer_did,
      started_at => E#file_download_started_v1.started_at}.

-spec from_map(map()) -> {ok, file_download_started_v1()} | {error, term()}.
from_map(Map) -> new(Map).
