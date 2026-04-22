%%% @doc Supervised worker that runs one download to completion.
%%%
%%% Started on-demand by `on_file_download_started_fetch_bytes` as a
%%% `simple_one_for_one` child under `briefcase_download_sup`. The
%%% worker's child id is the FileId so a second start for the same
%%% file can be detected + rejected (idempotent restart semantics).
%%%
%%% Lifecycle:
%%%   1. Seed progress ETS with phase=downloading, zero bytes.
%%%   2. Call `download_file_client:fetch/3` with a progress
%%%      callback that updates the ETS after every N frames.
%%%   3. On success: dispatch `complete_file_download_v1`, update
%%%      progress to phase=completed, shut down.
%%%   4. On failure: dispatch `fail_file_download_v1`, update
%%%      progress to phase=failed, shut down.
%%% @end
-module(briefcase_download_worker).
-behaviour(gen_server).

-export([start_link/3, start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2]).

-define(PROGRESS_UPDATE_EVERY_N_FRAMES, 4).

-record(state, {
    file_id      :: binary(),
    realm        :: binary(),
    total_size   :: non_neg_integer() | undefined,
    fetch_fn     :: fun((binary(), binary(), map()) -> term())
}).

%%====================================================================
%% API
%%====================================================================

%% @doc Start a worker. Default fetch_fn uses the real client.
start_link(FileId, Realm) ->
    start_link(FileId, Realm, fun download_file_client:fetch/3).

start_link(FileId, Realm, FetchFn)
  when is_binary(FileId), is_binary(Realm), is_function(FetchFn, 3) ->
    gen_server:start_link(?MODULE, {FileId, Realm, FetchFn}, []).

%%====================================================================
%% gen_server
%%====================================================================

init({FileId, Realm, FetchFn}) ->
    TotalHint = size_hint(FileId),
    ok = briefcase_download_progress:start_tick(FileId, TotalHint),
    self() ! run,
    {ok, #state{file_id = FileId, realm = Realm,
                total_size = TotalHint, fetch_fn = FetchFn}}.

handle_call(_, _From, State) -> {reply, {error, unknown_call}, State}.
handle_cast(_, State)        -> {noreply, State}.

handle_info(run, #state{file_id = FileId, realm = Realm,
                        fetch_fn = FetchFn} = State) ->
    Self = self(),
    Opts = #{
        progress_fn => fun(Bytes, Frames) ->
                           maybe_update_progress(Self, FileId, Bytes, Frames)
                       end
    },
    Result = try FetchFn(Realm, FileId, Opts)
             catch Class:Reason:_Stack ->
                 {error, {worker_crashed, Class, Reason}}
             end,
    finish(Result, State),
    {stop, normal, State};
handle_info(_, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.

%%====================================================================
%% Internal
%%====================================================================

size_hint(FileId) ->
    case catch project_briefcase_files_store:get(FileId) of
        {ok, #{size := Size}} when is_integer(Size) -> Size;
        _                                           -> undefined
    end.

%% Rate-limit ETS writes to every N frames — the callback fires per
%% frame but we don't need that resolution.
maybe_update_progress(_Self, FileId, Bytes, Frames)
  when Frames rem ?PROGRESS_UPDATE_EVERY_N_FRAMES == 0 ->
    briefcase_download_progress:update_bytes(FileId, Bytes, Frames);
maybe_update_progress(_, _, _, _) ->
    ok.

finish({ok, #{bytes_written := Bytes, frames := Frames}}, State) ->
    FileId = State#state.file_id,
    Realm = State#state.realm,
    briefcase_download_progress:mark_completed(FileId, Bytes, Frames),
    {ok, Cmd} = complete_file_download_v1:new(#{
        file_id      => FileId,
        source_realm => Realm,
        cache_size   => Bytes,
        frames       => Frames,
        completed_at => erlang:system_time(millisecond)}),
    case maybe_complete_file_download:dispatch(Cmd) of
        {ok, _, _} -> ok;
        {error, Reason} ->
            logger:warning(
                "[briefcase_download_worker] complete dispatch failed file=~s: ~p",
                [FileId, Reason])
    end;
finish({error, Reason}, State) ->
    FileId = State#state.file_id,
    PartialBytes = case briefcase_download_progress:get(FileId) of
        {ok, #{bytes_written := B}} -> B;
        _                           -> 0
    end,
    briefcase_download_progress:mark_failed(FileId, Reason, PartialBytes),
    {ok, Cmd} = fail_file_download_v1:new(#{
        file_id       => FileId,
        reason        => Reason,
        partial_bytes => PartialBytes,
        failed_at     => erlang:system_time(millisecond)}),
    case maybe_fail_file_download:dispatch(Cmd) of
        {ok, _, _} -> ok;
        {error, DispErr} ->
            logger:warning(
                "[briefcase_download_worker] fail dispatch failed file=~s: ~p",
                [FileId, DispErr])
    end.
