-module(briefcase_download_progress_tests).
-include_lib("eunit/include/eunit.hrl").

setup() ->
    %% Wipe both tables between tests; ensure_table/0 recreates.
    [delete(T) || T <- [briefcase_download_progress,
                        briefcase_download_workers]],
    briefcase_download_progress:ensure_table(),
    ok.

cleanup(_) ->
    [delete(T) || T <- [briefcase_download_progress,
                        briefcase_download_workers]],
    ok.

delete(Name) ->
    case ets:info(Name) of
        undefined -> ok;
        _         -> ets:delete(Name)
    end.

progress_test_() ->
    {foreach,
     fun setup/0,
     fun cleanup/1,
     [fun start_then_completed/1,
      fun start_then_failed/1,
      fun update_bytes_round_trip/1,
      fun mark_cancelled_keeps_other_fields/1,
      fun register_find_unregister_worker/1,
      fun find_worker_reaps_dead_pid/1]}.

start_then_completed(_) ->
    fun() ->
        ok = briefcase_download_progress:start_tick(<<"f1">>, 1024),
        {ok, Row} = briefcase_download_progress:get(<<"f1">>),
        ?assertEqual(downloading, maps:get(phase, Row)),
        ?assertEqual(1024, maps:get(total_size_hint, Row)),
        ok = briefcase_download_progress:mark_completed(<<"f1">>, 1024, 1),
        {ok, R2} = briefcase_download_progress:get(<<"f1">>),
        ?assertEqual(completed, maps:get(phase, R2)),
        ?assertEqual(1024, maps:get(bytes_written, R2))
    end.

start_then_failed(_) ->
    fun() ->
        ok = briefcase_download_progress:start_tick(<<"f2">>, undefined),
        ok = briefcase_download_progress:mark_failed(<<"f2">>, broken_pipe, 256),
        {ok, R} = briefcase_download_progress:get(<<"f2">>),
        ?assertEqual(failed, maps:get(phase, R)),
        ?assertEqual(broken_pipe, maps:get(reason, R)),
        ?assertEqual(256, maps:get(bytes_written, R))
    end.

update_bytes_round_trip(_) ->
    fun() ->
        ok = briefcase_download_progress:start_tick(<<"f3">>, 4096),
        ok = briefcase_download_progress:update_bytes(<<"f3">>, 2048, 32),
        {ok, R} = briefcase_download_progress:get(<<"f3">>),
        ?assertEqual(2048, maps:get(bytes_written, R)),
        ?assertEqual(32, maps:get(frames, R))
    end.

mark_cancelled_keeps_other_fields(_) ->
    fun() ->
        ok = briefcase_download_progress:start_tick(<<"f4">>, 100),
        ok = briefcase_download_progress:update_bytes(<<"f4">>, 50, 1),
        ok = briefcase_download_progress:mark_cancelled(<<"f4">>),
        {ok, R} = briefcase_download_progress:get(<<"f4">>),
        ?assertEqual(cancelled, maps:get(phase, R)),
        %% The bytes_written stays — useful for "cancelled at 50%".
        ?assertEqual(50, maps:get(bytes_written, R))
    end.

register_find_unregister_worker(_) ->
    fun() ->
        Pid = spawn(fun() -> receive die -> ok end end),
        briefcase_download_progress:register_worker(<<"f5">>, Pid),
        ?assertEqual({ok, Pid},
                     briefcase_download_progress:find_worker(<<"f5">>)),
        briefcase_download_progress:unregister_worker(<<"f5">>),
        ?assertEqual(not_found,
                     briefcase_download_progress:find_worker(<<"f5">>)),
        Pid ! die
    end.

find_worker_reaps_dead_pid(_) ->
    fun() ->
        Pid = spawn(fun() -> ok end),
        briefcase_download_progress:register_worker(<<"f6">>, Pid),
        %% Wait for the spawned process to exit naturally.
        timer:sleep(50),
        ?assertNot(is_process_alive(Pid)),
        ?assertEqual(not_found,
                     briefcase_download_progress:find_worker(<<"f6">>)),
        %% find_worker should have removed the stale entry.
        ?assertEqual([], ets:lookup(briefcase_download_workers, <<"f6">>))
    end.
