%%% @doc Layer 1: Dossier Tests -- Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since testing_state record is internal to testing_aggregate, we verify
%%% state correctness through execute/2 behavior (state machine guards)
%%% and through the behaviour callback apply/2.
-module(testing_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("test_division/include/testing_status.hrl").

%% Record field positions in testing_state (record tag is element 1)
-define(F_DIVISION_ID,   2).
-define(F_STATUS,        3).
-define(F_TEST_SUITES,   4).
-define(F_TEST_RESULTS,  5).
-define(F_STARTED_AT,    6).
-define(F_PAUSED_AT,     7).
-define(F_COMPLETED_AT,  8).
-define(F_PAUSE_REASON,  9).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"testing_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

suite_run_event() ->
    #{<<"event_type">> => <<"test_suite_run_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"suite_id">> => <<"suite-div-1-auth_tests">>,
      <<"suite_name">> => <<"auth_tests">>,
      <<"suite_type">> => <<"unit">>,
      <<"target_module">> => <<"auth_handler">>,
      <<"run_at">> => 2000}.

result_recorded_event() ->
    #{<<"event_type">> => <<"test_result_recorded_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"suite_id">> => <<"suite-div-1-auth_tests">>,
      <<"result_id">> => <<"result-suite-div-1-auth_tests-login_test">>,
      <<"test_name">> => <<"login_test">>,
      <<"status">> => <<"passed">>,
      <<"details">> => <<"All assertions passed">>,
      <<"recorded_at">> => 3000}.

pause_event() ->
    #{<<"event_type">> => <<"testing_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"blocking issue">>}.

resume_event() ->
    #{<<"event_type">> => <<"testing_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 5000}.

complete_event() ->
    #{<<"event_type">> => <<"testing_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event() ->
    #{<<"event_type">> => <<"testing_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin@host">>,
      <<"reason">> => <<"cleanup">>}.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% init/1 returns {ok, zeroed state}
initial_state_test() ->
    {ok, S} = testing_aggregate:init(<<"any-id">>),
    ?assertEqual(undefined, element(?F_DIVISION_ID, S)),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual(#{}, element(?F_TEST_SUITES, S)),
    ?assertEqual(#{}, element(?F_TEST_RESULTS, S)),
    ?assertEqual(undefined, element(?F_STARTED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S)),
    ?assertEqual(undefined, element(?F_COMPLETED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S)).

%% init/1 callback returns {ok, State}
init_callback_test() ->
    {ok, S} = testing_aggregate:init(<<"div-init">>),
    ?assertEqual(0, element(?F_STATUS, S)).

%% Apply testing_started_v1 sets INITIATED + ACTIVE, populates division_id
apply_start_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    Status = element(?F_STATUS, S1),
    ?assertNotEqual(0, Status band ?TESTING_INITIATED),
    ?assertNotEqual(0, Status band ?TESTING_ACTIVE),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(1000, element(?F_STARTED_AT, S1)).

%% Apply test_suite_run_v1 adds suite to test_suites map
apply_suite_run_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    S2 = testing_aggregate:apply(S1, suite_run_event()),
    Suites = element(?F_TEST_SUITES, S2),
    ?assert(maps:is_key(<<"suite-div-1-auth_tests">>, Suites)),
    Suite = maps:get(<<"suite-div-1-auth_tests">>, Suites),
    ?assertEqual(<<"suite-div-1-auth_tests">>, maps:get(suite_id, Suite)),
    ?assertEqual(<<"auth_tests">>, maps:get(suite_name, Suite)),
    ?assertEqual(<<"unit">>, maps:get(suite_type, Suite)),
    ?assertEqual(<<"auth_handler">>, maps:get(target_module, Suite)),
    ?assertEqual(2000, maps:get(run_at, Suite)).

%% Apply test_result_recorded_v1 adds result to test_results map
apply_result_recorded_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    S2 = testing_aggregate:apply(S1, suite_run_event()),
    S3 = testing_aggregate:apply(S2, result_recorded_event()),
    Results = element(?F_TEST_RESULTS, S3),
    ResultId = <<"result-suite-div-1-auth_tests-login_test">>,
    ?assert(maps:is_key(ResultId, Results)),
    Result = maps:get(ResultId, Results),
    ?assertEqual(ResultId, maps:get(result_id, Result)),
    ?assertEqual(<<"suite-div-1-auth_tests">>, maps:get(suite_id, Result)),
    ?assertEqual(<<"login_test">>, maps:get(test_name, Result)),
    ?assertEqual(<<"passed">>, maps:get(status, Result)),
    ?assertEqual(<<"All assertions passed">>, maps:get(details, Result)),
    ?assertEqual(3000, maps:get(recorded_at, Result)).

%% Apply testing_paused_v1 unsets ACTIVE, sets PAUSED, stores reason
apply_pause_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    S2 = testing_aggregate:apply(S1, pause_event()),
    Status = element(?F_STATUS, S2),
    ?assertEqual(0, Status band ?TESTING_ACTIVE),
    ?assertNotEqual(0, Status band ?TESTING_PAUSED),
    ?assertNotEqual(0, Status band ?TESTING_INITIATED),
    ?assertEqual(4000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"blocking issue">>, element(?F_PAUSE_REASON, S2)).

%% Apply testing_resumed_v1 unsets PAUSED, sets ACTIVE, clears pause fields
apply_resume_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    S2 = testing_aggregate:apply(S1, pause_event()),
    S3 = testing_aggregate:apply(S2, resume_event()),
    Status = element(?F_STATUS, S3),
    ?assertNotEqual(0, Status band ?TESTING_ACTIVE),
    ?assertEqual(0, Status band ?TESTING_PAUSED),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).

%% Apply testing_completed_v1 unsets ACTIVE, sets COMPLETED
apply_complete_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    S2 = testing_aggregate:apply(S1, complete_event()),
    Status = element(?F_STATUS, S2),
    ?assertEqual(0, Status band ?TESTING_ACTIVE),
    ?assertNotEqual(0, Status band ?TESTING_COMPLETED),
    ?assertNotEqual(0, Status band ?TESTING_INITIATED),
    ?assertEqual(6000, element(?F_COMPLETED_AT, S2)).

%% Apply testing_archived_v1 sets ARCHIVED bit
apply_archive_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    S2 = testing_aggregate:apply(S1, archive_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?TESTING_ARCHIVED),
    ?assertNotEqual(0, Status band ?TESTING_INITIATED).

%% Full lifecycle: start -> suite -> result -> pause -> resume -> complete -> archive
full_lifecycle_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    S2 = testing_aggregate:apply(S1, suite_run_event()),
    S3 = testing_aggregate:apply(S2, result_recorded_event()),
    S4 = testing_aggregate:apply(S3, pause_event()),
    S5 = testing_aggregate:apply(S4, resume_event()),
    S6 = testing_aggregate:apply(S5, complete_event()),
    S7 = testing_aggregate:apply(S6, archive_event()),
    Status = element(?F_STATUS, S7),
    %% INITIATED + COMPLETED + ARCHIVED should be set; ACTIVE and PAUSED unset
    ?assertNotEqual(0, Status band ?TESTING_INITIATED),
    ?assertNotEqual(0, Status band ?TESTING_COMPLETED),
    ?assertNotEqual(0, Status band ?TESTING_ARCHIVED),
    ?assertEqual(0, Status band ?TESTING_ACTIVE),
    ?assertEqual(0, Status band ?TESTING_PAUSED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S7)),
    %% Test suites and results preserved
    ?assertEqual(1, maps:size(element(?F_TEST_SUITES, S7))),
    ?assertEqual(1, maps:size(element(?F_TEST_RESULTS, S7))).

%% Unknown event leaves state unchanged
unknown_event_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    Unknown = #{<<"event_type">> => <<"some_random_event">>, <<"data">> => <<"whatever">>},
    S2 = testing_aggregate:apply(S1, Unknown),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
atom_keys_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    AtomEvent = #{event_type => <<"testing_started_v1">>,
                  division_id => <<"div-atom">>,
                  started_at => 9000,
                  started_by => <<"atom@host">>},
    S1 = testing_aggregate:apply(S0, AtomEvent),
    ?assertEqual(<<"div-atom">>, element(?F_DIVISION_ID, S1)),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?TESTING_INITIATED).

%% Flag map macro returns expected labels
flag_map_test() ->
    Map = ?TESTING_FLAG_MAP,
    ?assertEqual(<<"Initiated">>, maps:get(?TESTING_INITIATED, Map)),
    ?assertEqual(<<"Active">>, maps:get(?TESTING_ACTIVE, Map)),
    ?assertEqual(<<"Paused">>, maps:get(?TESTING_PAUSED, Map)),
    ?assertEqual(<<"Completed">>, maps:get(?TESTING_COMPLETED, Map)),
    ?assertEqual(<<"Archived">>, maps:get(?TESTING_ARCHIVED, Map)).

%% Behaviour callback: apply/2 takes (State, Event) -- state first
callback_order_test() ->
    {ok, S0} = testing_aggregate:init(<<"div-1">>),
    S1 = testing_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?TESTING_INITIATED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)).
