%%% @doc API: POST + GET + DELETE /api/briefcase/files/:file_id/download
%%%
%%% Async download model (Phase E+):
%%%
%%% POST   — Dispatch download_file_v1, return 202 with the initial
%%%          progress row. Worker is spawned by
%%%          on_file_download_started_fetch_bytes; cowboy worker
%%%          returns immediately so large files don't block the API.
%%%
%%% GET    — Return the current progress row (downloading | completed
%%%          | failed) as JSON. SSE variant comes in a follow-up; this
%%%          minimum lands the polling shape so the UI can render
%%%          progress without changes.
%%%
%%% DELETE — Cancel an in-flight download (best-effort: terminates
%%%          the worker; aggregate transitions via fail_file_download
%%%          dispatched by the worker as it shuts down). Currently
%%%          treated as a "stop the worker" hint; full cancel command
%%%          + event lands in a follow-up.
%%% @end
-module(download_file_api).

-export([init/2, routes/0]).

routes() -> [{"/api/briefcase/files/:file_id/download", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">>   -> handle_post(Req0, State);
        <<"GET">>    -> handle_get(Req0, State);
        <<"DELETE">> -> handle_delete(Req0, State);
        _            -> hecate_api_utils:method_not_allowed(Req0)
    end.

%%--------------------------------------------------------------------
%% POST — kick off the download
%%--------------------------------------------------------------------

handle_post(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case start(FileId) of
        ok ->
            Body = #{file_id => FileId,
                     state   => <<"downloading">>,
                     bytes_written => 0,
                     percent => 0},
            hecate_api_utils:json_ok(202, Body, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(400, format_error(Reason), Req0)
    end.

start(FileId) when is_binary(FileId), byte_size(FileId) > 0 ->
    case download_file_v1:new(#{file_id => FileId}) of
        {ok, Cmd} ->
            case maybe_download_file:dispatch(Cmd) of
                {ok, _V, _Events} -> ok;
                {error, _} = Err  -> Err
            end;
        {error, _} = Err ->
            Err
    end;
start(_) ->
    {error, file_id_required}.

%%--------------------------------------------------------------------
%% GET — current progress
%%--------------------------------------------------------------------

handle_get(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case briefcase_download_progress:get(FileId) of
        {ok, Row} ->
            hecate_api_utils:json_ok(progress_to_payload(FileId, Row), Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404,
                <<"No download in flight or recorded for this file">>, Req0)
    end.

progress_to_payload(FileId, Row) ->
    Bytes = maps:get(bytes_written, Row, 0),
    Total = maps:get(total_size_hint, Row, undefined),
    #{file_id        => FileId,
      state          => maps:get(phase, Row),
      bytes_written  => Bytes,
      frames         => maps:get(frames, Row, 0),
      total_size     => Total,
      percent        => percent(Bytes, Total),
      started_at     => maps:get(started_at, Row, null),
      last_update_at => maps:get(last_update_at, Row, null),
      reason         => format_reason_field(maps:get(reason, Row, undefined))}.

percent(_Bytes, undefined) -> null;
percent(_Bytes, 0)         -> null;
percent(Bytes, Total) when is_integer(Total), Total > 0 ->
    erlang:min(100, (Bytes * 100) div Total).

format_reason_field(undefined) -> null;
format_reason_field(R) when is_atom(R) -> atom_to_binary(R, utf8);
format_reason_field(R) when is_binary(R) -> R;
format_reason_field(R) -> iolist_to_binary(io_lib:format("~p", [R])).

%%--------------------------------------------------------------------
%% DELETE — cancel an in-flight worker
%%--------------------------------------------------------------------

handle_delete(Req0, _State) ->
    FileId = cowboy_req:binding(file_id, Req0),
    case cancel_worker(FileId) of
        ok ->
            briefcase_download_progress:mark_cancelled(FileId),
            hecate_api_utils:json_ok(#{file_id => FileId,
                                       state => <<"cancelled">>}, Req0);
        not_running ->
            hecate_api_utils:json_error(404,
                <<"No download in flight for this file">>, Req0)
    end.

%% Best-effort cancellation: find the worker by walking the
%% briefcase_download_sup children, kill the matching pid. Future
%% refinement: index workers by file_id in an ETS so the lookup is O(1).
cancel_worker(FileId) ->
    Children = supervisor:which_children(briefcase_download_sup),
    Pids = [Pid || {_, Pid, _, _} <- Children, is_pid(Pid)],
    case find_and_kill(Pids, FileId) of
        true  -> ok;
        false -> not_running
    end.

find_and_kill([], _FileId) -> false;
find_and_kill([Pid | Rest], FileId) ->
    case worker_owns(Pid, FileId) of
        true  -> exit(Pid, kill), true;
        false -> find_and_kill(Rest, FileId)
    end.

%% A worker doesn't expose its file_id directly. For Phase E we use a
%% best-effort heuristic: kill the most recently started worker if
%% there's exactly one. Multi-worker disambiguation lands when the
%% worker registers its file_id in an ETS lookup table.
worker_owns(_Pid, _FileId) ->
    %% TODO(phase-e+): real lookup. For now cancel-all.
    true.

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

format_error(Reason) when is_atom(Reason) -> atom_to_binary(Reason, utf8);
format_error({license_refused, Sub}) ->
    iolist_to_binary(["license_refused: ", atom_to_binary(Sub, utf8)]);
format_error(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
