%%% @doc Layer 2: Handler + Aggregate execute/2 tests.
%%% Tests handle/1 and handle/2 business logic and execute/2 state machine guards.
%%% No I/O -- builds state via apply/2 chains, then tests commands.
-module(test_division_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("test_division/include/testing_status.hrl").

%% Record field positions in testing_state
-define(F_DIVISION_ID,   2).
-define(F_STATUS,        3).
-define(F_TEST_SUITES,   4).
-define(F_TEST_RESULTS,  5).

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = testing_aggregate:init(<<"div-1">>),
    S.

started_state() ->
    testing_aggregate:apply(fresh_state(), start_event_map()).

paused_state() ->
    testing_aggregate:apply(started_state(), pause_event_map()).

completed_state() ->
    testing_aggregate:apply(started_state(), complete_event_map()).

archived_state() ->
    testing_aggregate:apply(started_state(), archive_event_map()).

%% State with a suite already run
state_with_suite() ->
    testing_aggregate:apply(started_state(), suite_run_event_map()).

%% State with a result already recorded
state_with_result() ->
    S1 = state_with_suite(),
    testing_aggregate:apply(S1, result_recorded_event_map()).

start_event_map() ->
    #{<<"event_type">> => <<"testing_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

suite_run_event_map() ->
    #{<<"event_type">> => <<"test_suite_run_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"suite_id">> => <<"suite-div-1-auth_tests">>,
      <<"suite_name">> => <<"auth_tests">>,
      <<"suite_type">> => <<"unit">>,
      <<"target_module">> => <<"auth_handler">>,
      <<"run_at">> => 2000}.

result_recorded_event_map() ->
    #{<<"event_type">> => <<"test_result_recorded_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"suite_id">> => <<"suite-div-1-auth_tests">>,
      <<"result_id">> => <<"result-suite-div-1-auth_tests-login_test">>,
      <<"test_name">> => <<"login_test">>,
      <<"status">> => <<"passed">>,
      <<"details">> => <<"ok">>,
      <<"recorded_at">> => 3000}.

pause_event_map() ->
    #{<<"event_type">> => <<"testing_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"blocked">>}.

complete_event_map() ->
    #{<<"event_type">> => <<"testing_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event_map() ->
    #{<<"event_type">> => <<"testing_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"cleanup">>}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% --- maybe_start_testing ---

handle_valid_start_test() ->
    {ok, Cmd} = start_testing_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_testing:handle(Cmd),
    Map = testing_started_v1:to_map(Event),
    ?assertEqual(<<"testing_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_start_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 start_testing_v1:new(#{division_id => <<>>})).

%% --- maybe_run_test_suite ---

handle_valid_run_suite_test() ->
    {ok, Cmd} = run_test_suite_v1:new(#{
        division_id => <<"div-1">>,
        suite_name => <<"auth_tests">>,
        suite_type => <<"unit">>,
        target_module => <<"auth_handler">>
    }),
    Context = #{test_suites => #{}},
    {ok, [Event]} = maybe_run_test_suite:handle(Cmd, Context),
    Map = test_suite_run_v1:to_map(Event),
    ?assertEqual(<<"test_suite_run_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"suite-div-1-auth_tests">>, maps:get(<<"suite_id">>, Map)),
    ?assertEqual(<<"auth_tests">>, maps:get(<<"suite_name">>, Map)),
    ?assertEqual(<<"unit">>, maps:get(<<"suite_type">>, Map)),
    ?assertEqual(<<"auth_handler">>, maps:get(<<"target_module">>, Map)).

handle_run_suite_already_run_test() ->
    {ok, Cmd} = run_test_suite_v1:new(#{
        division_id => <<"div-1">>,
        suite_name => <<"auth_tests">>
    }),
    ExistingSuites = #{<<"suite-div-1-auth_tests">> => #{suite_id => <<"suite-div-1-auth_tests">>}},
    Context = #{test_suites => ExistingSuites},
    ?assertEqual({error, suite_already_run},
                 maybe_run_test_suite:handle(Cmd, Context)).

handle_run_suite_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 run_test_suite_v1:new(#{division_id => <<>>, suite_name => <<"x">>})).

handle_run_suite_invalid_suite_name_test() ->
    ?assertEqual({error, {invalid_field, suite_name}},
                 run_test_suite_v1:new(#{division_id => <<"div-1">>, suite_name => <<>>})).

%% --- maybe_record_test_result ---

handle_valid_record_result_test() ->
    {ok, Cmd} = record_test_result_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"suite-div-1-auth_tests">>,
        test_name => <<"login_test">>,
        status => <<"passed">>,
        details => <<"All good">>
    }),
    Context = #{test_results => #{}},
    {ok, [Event]} = maybe_record_test_result:handle(Cmd, Context),
    Map = test_result_recorded_v1:to_map(Event),
    ?assertEqual(<<"test_result_recorded_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"result-suite-div-1-auth_tests-login_test">>, maps:get(<<"result_id">>, Map)),
    ?assertEqual(<<"suite-div-1-auth_tests">>, maps:get(<<"suite_id">>, Map)),
    ?assertEqual(<<"login_test">>, maps:get(<<"test_name">>, Map)),
    ?assertEqual(<<"passed">>, maps:get(<<"status">>, Map)),
    ?assertEqual(<<"All good">>, maps:get(<<"details">>, Map)).

handle_record_result_already_recorded_test() ->
    {ok, Cmd} = record_test_result_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"suite-div-1-auth_tests">>,
        test_name => <<"login_test">>,
        status => <<"passed">>
    }),
    ResultId = <<"result-suite-div-1-auth_tests-login_test">>,
    ExistingResults = #{ResultId => #{result_id => ResultId}},
    Context = #{test_results => ExistingResults},
    ?assertEqual({error, result_already_recorded},
                 maybe_record_test_result:handle(Cmd, Context)).

handle_record_result_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 record_test_result_v1:new(#{division_id => <<>>,
                                             suite_id => <<"s">>,
                                             test_name => <<"t">>})).

handle_record_result_invalid_suite_id_test() ->
    ?assertEqual({error, {invalid_field, suite_id}},
                 record_test_result_v1:new(#{division_id => <<"d">>,
                                             suite_id => <<>>,
                                             test_name => <<"t">>})).

handle_record_result_invalid_test_name_test() ->
    ?assertEqual({error, {invalid_field, test_name}},
                 record_test_result_v1:new(#{division_id => <<"d">>,
                                             suite_id => <<"s">>,
                                             test_name => <<>>})).

%% --- maybe_pause_testing ---

handle_valid_pause_test() ->
    {ok, Cmd} = pause_testing_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"infrastructure down">>
    }),
    {ok, [Event]} = maybe_pause_testing:handle(Cmd),
    Map = testing_paused_v1:to_map(Event),
    ?assertEqual(<<"testing_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"infrastructure down">>, maps:get(<<"reason">>, Map)).

handle_pause_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 pause_testing_v1:new(#{division_id => <<>>})).

%% --- maybe_resume_testing ---

handle_valid_resume_test() ->
    {ok, Cmd} = resume_testing_v1:new(#{division_id => <<"div-1">>}),
    {ok, [Event]} = maybe_resume_testing:handle(Cmd),
    Map = testing_resumed_v1:to_map(Event),
    ?assertEqual(<<"testing_resumed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_resume_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 resume_testing_v1:new(#{division_id => <<>>})).

%% --- maybe_complete_testing ---

handle_valid_complete_test() ->
    {ok, Cmd} = complete_testing_v1:new(#{division_id => <<"div-1">>}),
    {ok, [Event]} = maybe_complete_testing:handle(Cmd),
    Map = testing_completed_v1:to_map(Event),
    ?assertEqual(<<"testing_completed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

handle_complete_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 complete_testing_v1:new(#{division_id => <<>>})).

%% --- maybe_archive_testing ---

handle_valid_archive_test() ->
    {ok, Cmd} = archive_testing_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_testing:handle(Cmd),
    Map = testing_archived_v1:to_map(Event),
    ?assertEqual(<<"testing_archived_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

handle_archive_invalid_division_id_test() ->
    ?assertEqual({error, {invalid_field, division_id}},
                 archive_testing_v1:new(#{division_id => <<>>})).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_testing command ---

execute_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"start_testing">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = testing_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"testing_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_already_started_test() ->
    Cmd = #{<<"command_type">> => <<"start_testing">>,
            <<"division_id">> => <<"div-1">>},
    %% On started state, status =/= 0, so start_testing is routed to execute_lifecycle
    %% which doesn't match "start_testing", falls through to unknown_command
    Result = testing_aggregate:execute(started_state(), Cmd),
    ?assertMatch({error, _}, Result).

%% Non-start commands on fresh state yield testing_not_started
execute_run_suite_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"run_test_suite">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_name">> => <<"auth_tests">>},
    ?assertEqual({error, testing_not_started},
                 testing_aggregate:execute(fresh_state(), Cmd)).

%% --- run_test_suite command ---

execute_run_suite_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"run_test_suite">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_name">> => <<"auth_tests">>,
            <<"suite_type">> => <<"unit">>,
            <<"target_module">> => <<"auth_handler">>},
    {ok, [EventMap]} = testing_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"test_suite_run_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_run_suite_not_active_paused_test() ->
    Cmd = #{<<"command_type">> => <<"run_test_suite">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_name">> => <<"tests">>},
    ?assertMatch({error, {not_active, _}},
                 testing_aggregate:execute(paused_state(), Cmd)).

execute_run_suite_not_active_completed_test() ->
    Cmd = #{<<"command_type">> => <<"run_test_suite">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_name">> => <<"tests">>},
    ?assertMatch({error, {not_active, _}},
                 testing_aggregate:execute(completed_state(), Cmd)).

execute_run_suite_duplicate_test() ->
    Cmd = #{<<"command_type">> => <<"run_test_suite">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_name">> => <<"auth_tests">>},
    ?assertEqual({error, suite_already_run},
                 testing_aggregate:execute(state_with_suite(), Cmd)).

%% --- record_test_result command ---

execute_record_result_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"record_test_result">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_id">> => <<"suite-div-1-auth_tests">>,
            <<"test_name">> => <<"login_test">>,
            <<"status">> => <<"passed">>},
    {ok, [EventMap]} = testing_aggregate:execute(state_with_suite(), Cmd),
    ?assertEqual(<<"test_result_recorded_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_record_result_not_active_paused_test() ->
    Cmd = #{<<"command_type">> => <<"record_test_result">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_id">> => <<"s">>,
            <<"test_name">> => <<"t">>},
    ?assertMatch({error, {not_active, _}},
                 testing_aggregate:execute(paused_state(), Cmd)).

execute_record_result_duplicate_test() ->
    Cmd = #{<<"command_type">> => <<"record_test_result">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_id">> => <<"suite-div-1-auth_tests">>,
            <<"test_name">> => <<"login_test">>,
            <<"status">> => <<"passed">>},
    ?assertEqual({error, result_already_recorded},
                 testing_aggregate:execute(state_with_result(), Cmd)).

%% --- pause_testing command ---

execute_pause_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"pause_testing">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = testing_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"testing_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_testing">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 testing_aggregate:execute(paused_state(), Cmd)).

execute_pause_not_active_completed_test() ->
    Cmd = #{<<"command_type">> => <<"pause_testing">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 testing_aggregate:execute(completed_state(), Cmd)).

%% --- resume_testing command ---

execute_resume_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"resume_testing">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = testing_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"testing_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_not_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_testing">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_paused, _}},
                 testing_aggregate:execute(started_state(), Cmd)).

execute_resume_not_paused_completed_test() ->
    Cmd = #{<<"command_type">> => <<"resume_testing">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_paused, _}},
                 testing_aggregate:execute(completed_state(), Cmd)).

%% --- complete_testing command ---

execute_complete_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"complete_testing">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = testing_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"testing_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_testing">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 testing_aggregate:execute(paused_state(), Cmd)).

execute_complete_not_active_completed_test() ->
    Cmd = #{<<"command_type">> => <<"complete_testing">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 testing_aggregate:execute(completed_state(), Cmd)).

%% --- archive_testing command ---

execute_archive_on_started_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_testing">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = testing_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"testing_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_testing">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = testing_aggregate:execute(completed_state(), Cmd),
    ?assertEqual(<<"testing_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_testing">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = testing_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"testing_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_testing">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, testing_archived},
                 testing_aggregate:execute(archived_state(), Cmd)).

%% --- unknown command ---

execute_unknown_command_on_fresh_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, testing_not_started},
                 testing_aggregate:execute(fresh_state(), Cmd)).

execute_unknown_command_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 testing_aggregate:execute(started_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertEqual({error, testing_not_started},
                 testing_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_testing">>,
                <<"division_id">> => <<"div-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = testing_aggregate:execute(State, Payload).

%% --- all commands on archived state yield testing_archived ---

execute_all_commands_on_archived_test() ->
    Commands = [
        #{<<"command_type">> => <<"run_test_suite">>,
          <<"division_id">> => <<"div-1">>,
          <<"suite_name">> => <<"x">>},
        #{<<"command_type">> => <<"record_test_result">>,
          <<"division_id">> => <<"div-1">>,
          <<"suite_id">> => <<"s">>,
          <<"test_name">> => <<"t">>},
        #{<<"command_type">> => <<"pause_testing">>,
          <<"division_id">> => <<"div-1">>},
        #{<<"command_type">> => <<"resume_testing">>,
          <<"division_id">> => <<"div-1">>},
        #{<<"command_type">> => <<"complete_testing">>,
          <<"division_id">> => <<"div-1">>},
        #{<<"command_type">> => <<"archive_testing">>,
          <<"division_id">> => <<"div-1">>}
    ],
    lists:foreach(fun(Cmd) ->
        ?assertEqual({error, testing_archived},
                     testing_aggregate:execute(archived_state(), Cmd))
    end, Commands).
