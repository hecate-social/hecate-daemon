%%% @doc State-transition tests for Phase E download + evict
%%% lifecycle on the briefcase aggregate.
%%%
%%% Covers the execute/2 gates only — no crypto, no network. Execute
%%% returns early with the right error atom on each invalid
%%% transition. The happy paths (which require mesh + CEK lookup)
%%% are exercised in integration tests.
-module(briefcase_aggregate_download_evict_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_briefcase_lifecycle/include/briefcase_state.hrl").
-include_lib("guide_briefcase_lifecycle/include/briefcase_status.hrl").

%%====================================================================
%% download_file_v1 gate
%%====================================================================

download_requires_announced_test() ->
    %% status = 0, i.e. nothing has been established about this file.
    State = briefcase_state:new(<<"file-1">>),
    Payload = download_payload(<<"file-1">>),
    ?assertEqual({error, not_announced},
                 briefcase_aggregate:execute(State, Payload)).

download_rejected_if_locally_uploaded_test() ->
    State0 = briefcase_state:new(<<"file-2">>),
    State = with_flag(State0, ?FILE_UPLOADED),
    Payload = download_payload(<<"file-2">>),
    ?assertEqual({error, locally_uploaded},
                 briefcase_aggregate:execute(State, Payload)).

download_rejected_if_already_cached_test() ->
    State0 = briefcase_state:new(<<"file-3">>),
    State = with_flags(State0, [?FILE_ANNOUNCED, ?FILE_CACHED]),
    Payload = download_payload(<<"file-3">>),
    ?assertEqual({error, already_cached},
                 briefcase_aggregate:execute(State, Payload)).

%%====================================================================
%% evict_file_v1 gate
%%====================================================================

evict_rejected_if_not_cached_test() ->
    State0 = briefcase_state:new(<<"file-4">>),
    State = with_flag(State0, ?FILE_ANNOUNCED),
    Payload = evict_payload(<<"file-4">>),
    ?assertEqual({error, not_cached},
                 briefcase_aggregate:execute(State, Payload)).

evict_on_fresh_state_rejected_test() ->
    State = briefcase_state:new(<<"file-5">>),
    Payload = evict_payload(<<"file-5">>),
    ?assertEqual({error, not_cached},
                 briefcase_aggregate:execute(State, Payload)).

%%====================================================================
%% State folds
%%====================================================================

apply_file_cached_sets_flag_test() ->
    State0 = briefcase_state:new(<<"file-6">>),
    Cached = #{event_type => <<"file_cached_v1">>,
               file_id    => <<"file-6">>,
               cache_size => 1024,
               frames     => 1,
               source_realm => <<"io.macula">>,
               cached_at  => 1234},
    State = briefcase_aggregate:apply(State0, Cached),
    ?assert(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_CACHED)).

apply_file_evicted_clears_flag_test() ->
    State0 = briefcase_state:new(<<"file-7">>),
    State1 = with_flag(State0, ?FILE_CACHED),
    Evicted = #{event_type => <<"file_evicted_v1">>,
                file_id    => <<"file-7">>,
                evicted_at => 2000},
    State2 = briefcase_aggregate:apply(State1, Evicted),
    ?assertNot(evoq_bit_flags:has(State2#briefcase_state.status, ?FILE_CACHED)).

%%====================================================================
%% Async download model — new event folds + gates
%%====================================================================

apply_file_download_started_sets_downloading_test() ->
    State0 = briefcase_state:new(<<"file-d">>),
    Started = #{event_type => <<"file_download_started_v1">>,
                file_id => <<"file-d">>,
                realm => <<"io.macula">>,
                started_at => 1000},
    State = briefcase_aggregate:apply(State0, Started),
    ?assert(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_DOWNLOADING)),
    %% FILE_CACHED stays clear
    ?assertNot(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_CACHED)).

apply_file_download_completed_sets_cached_clears_downloading_test() ->
    State0 = briefcase_state:new(<<"file-c">>),
    State1 = with_flag(State0, ?FILE_DOWNLOADING),
    Completed = #{event_type => <<"file_download_completed_v1">>,
                  file_id => <<"file-c">>,
                  source_realm => <<"io.macula">>,
                  cache_size => 2048,
                  frames => 2,
                  completed_at => 9999},
    State = briefcase_aggregate:apply(State1, Completed),
    ?assert(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_CACHED)),
    ?assertNot(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_DOWNLOADING)).

apply_file_download_failed_clears_downloading_test() ->
    State0 = briefcase_state:new(<<"file-f">>),
    State1 = with_flag(State0, ?FILE_DOWNLOADING),
    Failed = #{event_type => <<"file_download_failed_v1">>,
               file_id => <<"file-f">>,
               reason => stream_ended_without_eof_frame,
               partial_bytes => 512,
               failed_at => 999},
    State = briefcase_aggregate:apply(State1, Failed),
    ?assertNot(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_DOWNLOADING)),
    ?assertNot(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_CACHED)).

legacy_file_cached_v1_treated_as_completed_test() ->
    %% Replay safety: a stream that emitted the synchronous-Phase-E
    %% file_cached_v1 should reconstruct to the same state as a new
    %% file_download_completed_v1 (FILE_CACHED set, FILE_DOWNLOADING
    %% clear).
    State0 = briefcase_state:new(<<"file-l">>),
    State1 = with_flag(State0, ?FILE_DOWNLOADING),  %% simulate mid-flight
    Legacy = #{event_type => <<"file_cached_v1">>,
               file_id => <<"file-l">>,
               cache_size => 1024,
               frames => 1,
               source_realm => <<"io.macula">>,
               cached_at => 1234},
    State = briefcase_aggregate:apply(State1, Legacy),
    ?assert(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_CACHED)),
    ?assertNot(evoq_bit_flags:has(State#briefcase_state.status, ?FILE_DOWNLOADING)).

download_rejected_if_already_downloading_test() ->
    State0 = briefcase_state:new(<<"file-id">>),
    State = with_flags(State0, [?FILE_ANNOUNCED, ?FILE_DOWNLOADING]),
    Payload = download_payload(<<"file-id">>),
    ?assertEqual({error, already_downloading},
                 briefcase_aggregate:execute(State, Payload)).

complete_rejected_if_not_downloading_test() ->
    %% complete_file_download_v1 is dispatched by the worker — it
    %% should never reach the aggregate without FILE_DOWNLOADING set.
    State0 = briefcase_state:new(<<"file-c2">>),
    State = with_flag(State0, ?FILE_ANNOUNCED),
    Payload = #{command_type => complete_file_download_v1,
                file_id => <<"file-c2">>,
                source_realm => <<"io.macula">>,
                cache_size => 1024,
                frames => 1,
                completed_at => 5000},
    ?assertEqual({error, not_downloading},
                 briefcase_aggregate:execute(State, Payload)).

fail_rejected_if_not_downloading_test() ->
    State0 = briefcase_state:new(<<"file-f2">>),
    State = with_flag(State0, ?FILE_ANNOUNCED),
    Payload = #{command_type => fail_file_download_v1,
                file_id => <<"file-f2">>,
                reason => some_error},
    ?assertEqual({error, not_downloading},
                 briefcase_aggregate:execute(State, Payload)).

%%====================================================================
%% Helpers
%%====================================================================

download_payload(FileId) ->
    #{command_type => download_file_v1,
      file_id      => FileId}.

evict_payload(FileId) ->
    #{command_type => evict_file_v1,
      file_id      => FileId}.

with_flag(State, Flag) ->
    State#briefcase_state{
        status = evoq_bit_flags:set(State#briefcase_state.status, Flag)
    }.

with_flags(State, Flags) ->
    lists:foldl(fun(F, S) -> with_flag(S, F) end, State, Flags).
