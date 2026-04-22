%%% @doc Progress ETS for in-flight briefcase downloads.
%%%
%%% Owner: `guide_briefcase_lifecycle_sup` (creates the table on
%%% start so any subsequent worker write is safe). A worker updates
%%% the row on each chunk; the progress API endpoint reads it to
%%% surface percent-complete / bytes-written to the UI.
%%%
%%% Row shape:
%%% ```
%%% #{file_id, phase, bytes_written, frames, started_at,
%%%   last_update_at, total_size_hint, reason}
%%% ```
%%%
%%% `phase` is one of `downloading | completed | failed | cancelled`.
%%% `total_size_hint` is populated from the briefcase_files row if
%%% available; `null` on first tick before the worker sees it.
%%% @end
-module(briefcase_download_progress).

-export([ensure_table/0, start_tick/2, update_bytes/3,
         mark_completed/3, mark_failed/3, mark_cancelled/1,
         get/1, list/0, erase/1]).

-define(TABLE, briefcase_download_progress).

ensure_table() ->
    case ets:info(?TABLE) of
        undefined ->
            ets:new(?TABLE, [public, named_table, set,
                             {read_concurrency, true},
                             {write_concurrency, true}]);
        _ -> ok
    end.

%% @doc Seed a new row at download start. `TotalSizeHint` may be
%% `undefined` when the caller doesn't know the file size yet.
-spec start_tick(binary(), non_neg_integer() | undefined) -> ok.
start_tick(FileId, TotalSizeHint) ->
    ensure_table(),
    Now = erlang:system_time(millisecond),
    Row = #{file_id          => FileId,
            phase            => downloading,
            bytes_written    => 0,
            frames           => 0,
            started_at       => Now,
            last_update_at   => Now,
            total_size_hint  => TotalSizeHint,
            reason           => undefined},
    ets:insert(?TABLE, {FileId, Row}),
    ok.

-spec update_bytes(binary(), non_neg_integer(), non_neg_integer()) -> ok.
update_bytes(FileId, Bytes, Frames) ->
    ensure_table(),
    case ets:lookup(?TABLE, FileId) of
        [{_, Row}] ->
            ets:insert(?TABLE,
                       {FileId, Row#{bytes_written => Bytes,
                                     frames => Frames,
                                     last_update_at =>
                                         erlang:system_time(millisecond)}}),
            ok;
        [] ->
            ok
    end.

-spec mark_completed(binary(), non_neg_integer(), non_neg_integer()) -> ok.
mark_completed(FileId, Bytes, Frames) ->
    ensure_table(),
    Now = erlang:system_time(millisecond),
    case ets:lookup(?TABLE, FileId) of
        [{_, Row}] ->
            ets:insert(?TABLE,
                       {FileId, Row#{phase => completed,
                                     bytes_written => Bytes,
                                     frames => Frames,
                                     last_update_at => Now}}),
            ok;
        [] ->
            Row = #{file_id => FileId, phase => completed,
                    bytes_written => Bytes, frames => Frames,
                    started_at => Now, last_update_at => Now,
                    total_size_hint => undefined, reason => undefined},
            ets:insert(?TABLE, {FileId, Row}),
            ok
    end.

-spec mark_failed(binary(), term(), non_neg_integer()) -> ok.
mark_failed(FileId, Reason, PartialBytes) ->
    ensure_table(),
    Now = erlang:system_time(millisecond),
    case ets:lookup(?TABLE, FileId) of
        [{_, Row}] ->
            ets:insert(?TABLE,
                       {FileId, Row#{phase => failed,
                                     bytes_written => PartialBytes,
                                     reason => Reason,
                                     last_update_at => Now}}),
            ok;
        [] ->
            ok
    end.

-spec mark_cancelled(binary()) -> ok.
mark_cancelled(FileId) ->
    ensure_table(),
    case ets:lookup(?TABLE, FileId) of
        [{_, Row}] ->
            ets:insert(?TABLE,
                       {FileId, Row#{phase => cancelled,
                                     last_update_at =>
                                         erlang:system_time(millisecond)}}),
            ok;
        [] -> ok
    end.

-spec get(binary()) -> {ok, map()} | {error, not_found}.
get(FileId) ->
    case ets:info(?TABLE) of
        undefined -> {error, not_found};
        _ ->
            case ets:lookup(?TABLE, FileId) of
                [{_, Row}] -> {ok, Row};
                []         -> {error, not_found}
            end
    end.

-spec list() -> {ok, [map()]}.
list() ->
    case ets:info(?TABLE) of
        undefined -> {ok, []};
        _ -> {ok, [Row || {_, Row} <- ets:tab2list(?TABLE)]}
    end.

-spec erase(binary()) -> ok.
erase(FileId) ->
    case ets:info(?TABLE) of
        undefined -> ok;
        _ -> ets:delete(?TABLE, FileId), ok
    end.
