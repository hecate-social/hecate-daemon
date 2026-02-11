%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
-module(testing_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% testing_started_v1 event tests
%% ===================================================================

testing_started_v1_new_test() ->
    E = testing_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    ?assertEqual(<<"div-1">>, testing_started_v1:get_division_id(E)),
    ?assertEqual(<<"user@host">>, testing_started_v1:get_started_by(E)),
    ?assert(is_integer(testing_started_v1:get_started_at(E))).

testing_started_v1_to_map_includes_event_type_test() ->
    E = testing_started_v1:new(#{division_id => <<"d">>}),
    Map = testing_started_v1:to_map(E),
    ?assertEqual(<<"testing_started_v1">>, maps:get(<<"event_type">>, Map)).

testing_started_v1_round_trip_test() ->
    E = testing_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user">>,
        started_at => 12345
    }),
    Map = testing_started_v1:to_map(E),
    {ok, E2} = testing_started_v1:from_map(Map),
    ?assertEqual(testing_started_v1:get_division_id(E),
                 testing_started_v1:get_division_id(E2)),
    ?assertEqual(testing_started_v1:get_started_by(E),
                 testing_started_v1:get_started_by(E2)),
    ?assertEqual(testing_started_v1:get_started_at(E),
                 testing_started_v1:get_started_at(E2)).

testing_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = testing_started_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = testing_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% test_suite_run_v1 event tests
%% ===================================================================

test_suite_run_v1_new_test() ->
    E = test_suite_run_v1:new(#{
        division_id => <<"div-1">>,
        suite_name => <<"auth_tests">>,
        suite_type => <<"integration">>,
        target_module => <<"auth_handler">>
    }),
    ?assertEqual(<<"div-1">>, test_suite_run_v1:get_division_id(E)),
    ?assertEqual(<<"auth_tests">>, test_suite_run_v1:get_suite_name(E)),
    ?assertEqual(<<"integration">>, test_suite_run_v1:get_suite_type(E)),
    ?assertEqual(<<"auth_handler">>, test_suite_run_v1:get_target_module(E)),
    ?assert(is_integer(test_suite_run_v1:get_run_at(E))).

test_suite_run_v1_suite_id_deterministic_test() ->
    E = test_suite_run_v1:new(#{
        division_id => <<"div-1">>,
        suite_name => <<"auth_tests">>
    }),
    ?assertEqual(<<"suite-div-1-auth_tests">>, test_suite_run_v1:get_suite_id(E)).

test_suite_run_v1_to_map_includes_event_type_test() ->
    E = test_suite_run_v1:new(#{division_id => <<"d">>, suite_name => <<"s">>}),
    Map = test_suite_run_v1:to_map(E),
    ?assertEqual(<<"test_suite_run_v1">>, maps:get(<<"event_type">>, Map)).

test_suite_run_v1_round_trip_test() ->
    E = test_suite_run_v1:new(#{
        division_id => <<"div-1">>,
        suite_name => <<"auth_tests">>,
        suite_type => <<"unit">>,
        target_module => <<"auth">>,
        run_at => 5000
    }),
    Map = test_suite_run_v1:to_map(E),
    {ok, E2} = test_suite_run_v1:from_map(Map),
    ?assertEqual(test_suite_run_v1:get_division_id(E),
                 test_suite_run_v1:get_division_id(E2)),
    ?assertEqual(test_suite_run_v1:get_suite_id(E),
                 test_suite_run_v1:get_suite_id(E2)),
    ?assertEqual(test_suite_run_v1:get_suite_name(E),
                 test_suite_run_v1:get_suite_name(E2)),
    ?assertEqual(test_suite_run_v1:get_suite_type(E),
                 test_suite_run_v1:get_suite_type(E2)),
    ?assertEqual(test_suite_run_v1:get_target_module(E),
                 test_suite_run_v1:get_target_module(E2)),
    ?assertEqual(test_suite_run_v1:get_run_at(E),
                 test_suite_run_v1:get_run_at(E2)).

test_suite_run_v1_defaults_test() ->
    E = test_suite_run_v1:new(#{
        division_id => <<"div-1">>,
        suite_name => <<"basic">>
    }),
    ?assertEqual(<<"unit">>, test_suite_run_v1:get_suite_type(E)),
    ?assertEqual(<<>>, test_suite_run_v1:get_target_module(E)).

%% ===================================================================
%% test_result_recorded_v1 event tests
%% ===================================================================

test_result_recorded_v1_new_test() ->
    E = test_result_recorded_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"suite-div-1-auth">>,
        test_name => <<"login_test">>,
        status => <<"passed">>,
        details => <<"All good">>
    }),
    ?assertEqual(<<"div-1">>, test_result_recorded_v1:get_division_id(E)),
    ?assertEqual(<<"suite-div-1-auth">>, test_result_recorded_v1:get_suite_id(E)),
    ?assertEqual(<<"login_test">>, test_result_recorded_v1:get_test_name(E)),
    ?assertEqual(<<"passed">>, test_result_recorded_v1:get_status(E)),
    ?assertEqual(<<"All good">>, test_result_recorded_v1:get_details(E)),
    ?assert(is_integer(test_result_recorded_v1:get_recorded_at(E))).

test_result_recorded_v1_result_id_deterministic_test() ->
    E = test_result_recorded_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"suite-div-1-auth">>,
        test_name => <<"login_test">>
    }),
    ?assertEqual(<<"result-suite-div-1-auth-login_test">>,
                 test_result_recorded_v1:get_result_id(E)).

test_result_recorded_v1_to_map_includes_event_type_test() ->
    E = test_result_recorded_v1:new(#{
        division_id => <<"d">>,
        suite_id => <<"s">>,
        test_name => <<"t">>
    }),
    Map = test_result_recorded_v1:to_map(E),
    ?assertEqual(<<"test_result_recorded_v1">>, maps:get(<<"event_type">>, Map)).

test_result_recorded_v1_round_trip_test() ->
    E = test_result_recorded_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"suite-div-1-auth">>,
        test_name => <<"login_test">>,
        status => <<"failed">>,
        details => <<"assertion error">>,
        recorded_at => 8000
    }),
    Map = test_result_recorded_v1:to_map(E),
    {ok, E2} = test_result_recorded_v1:from_map(Map),
    ?assertEqual(test_result_recorded_v1:get_division_id(E),
                 test_result_recorded_v1:get_division_id(E2)),
    ?assertEqual(test_result_recorded_v1:get_result_id(E),
                 test_result_recorded_v1:get_result_id(E2)),
    ?assertEqual(test_result_recorded_v1:get_suite_id(E),
                 test_result_recorded_v1:get_suite_id(E2)),
    ?assertEqual(test_result_recorded_v1:get_test_name(E),
                 test_result_recorded_v1:get_test_name(E2)),
    ?assertEqual(test_result_recorded_v1:get_status(E),
                 test_result_recorded_v1:get_status(E2)),
    ?assertEqual(test_result_recorded_v1:get_details(E),
                 test_result_recorded_v1:get_details(E2)),
    ?assertEqual(test_result_recorded_v1:get_recorded_at(E),
                 test_result_recorded_v1:get_recorded_at(E2)).

test_result_recorded_v1_defaults_test() ->
    E = test_result_recorded_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"s">>,
        test_name => <<"t">>
    }),
    ?assertEqual(<<"unknown">>, test_result_recorded_v1:get_status(E)),
    ?assertEqual(undefined, test_result_recorded_v1:get_details(E)).

%% ===================================================================
%% testing_paused_v1 event tests
%% ===================================================================

testing_paused_v1_new_test() ->
    E = testing_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"infrastructure down">>
    }),
    ?assertEqual(<<"div-1">>, testing_paused_v1:get_division_id(E)),
    ?assertEqual(<<"infrastructure down">>, testing_paused_v1:get_reason(E)),
    ?assert(is_integer(testing_paused_v1:get_paused_at(E))).

testing_paused_v1_to_map_includes_event_type_test() ->
    E = testing_paused_v1:new(#{division_id => <<"d">>}),
    Map = testing_paused_v1:to_map(E),
    ?assertEqual(<<"testing_paused_v1">>, maps:get(<<"event_type">>, Map)).

testing_paused_v1_round_trip_test() ->
    E = testing_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"blocked">>,
        paused_at => 9000
    }),
    Map = testing_paused_v1:to_map(E),
    {ok, E2} = testing_paused_v1:from_map(Map),
    ?assertEqual(testing_paused_v1:get_division_id(E),
                 testing_paused_v1:get_division_id(E2)),
    ?assertEqual(testing_paused_v1:get_reason(E),
                 testing_paused_v1:get_reason(E2)),
    ?assertEqual(testing_paused_v1:get_paused_at(E),
                 testing_paused_v1:get_paused_at(E2)).

testing_paused_v1_reason_defaults_to_undefined_test() ->
    E = testing_paused_v1:new(#{division_id => <<"d">>}),
    ?assertEqual(undefined, testing_paused_v1:get_reason(E)).

%% ===================================================================
%% testing_resumed_v1 event tests
%% ===================================================================

testing_resumed_v1_new_test() ->
    E = testing_resumed_v1:new(#{division_id => <<"div-1">>}),
    ?assertEqual(<<"div-1">>, testing_resumed_v1:get_division_id(E)),
    ?assert(is_integer(testing_resumed_v1:get_resumed_at(E))).

testing_resumed_v1_to_map_includes_event_type_test() ->
    E = testing_resumed_v1:new(#{division_id => <<"d">>}),
    Map = testing_resumed_v1:to_map(E),
    ?assertEqual(<<"testing_resumed_v1">>, maps:get(<<"event_type">>, Map)).

testing_resumed_v1_round_trip_test() ->
    E = testing_resumed_v1:new(#{
        division_id => <<"div-1">>,
        resumed_at => 10000
    }),
    Map = testing_resumed_v1:to_map(E),
    {ok, E2} = testing_resumed_v1:from_map(Map),
    ?assertEqual(testing_resumed_v1:get_division_id(E),
                 testing_resumed_v1:get_division_id(E2)),
    ?assertEqual(testing_resumed_v1:get_resumed_at(E),
                 testing_resumed_v1:get_resumed_at(E2)).

testing_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = testing_resumed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = testing_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% testing_completed_v1 event tests
%% ===================================================================

testing_completed_v1_new_test() ->
    E = testing_completed_v1:new(#{division_id => <<"div-1">>}),
    ?assertEqual(<<"div-1">>, testing_completed_v1:get_division_id(E)),
    ?assert(is_integer(testing_completed_v1:get_completed_at(E))).

testing_completed_v1_to_map_includes_event_type_test() ->
    E = testing_completed_v1:new(#{division_id => <<"d">>}),
    Map = testing_completed_v1:to_map(E),
    ?assertEqual(<<"testing_completed_v1">>, maps:get(<<"event_type">>, Map)).

testing_completed_v1_round_trip_test() ->
    E = testing_completed_v1:new(#{
        division_id => <<"div-1">>,
        completed_at => 11000
    }),
    Map = testing_completed_v1:to_map(E),
    {ok, E2} = testing_completed_v1:from_map(Map),
    ?assertEqual(testing_completed_v1:get_division_id(E),
                 testing_completed_v1:get_division_id(E2)),
    ?assertEqual(testing_completed_v1:get_completed_at(E),
                 testing_completed_v1:get_completed_at(E2)).

testing_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = testing_completed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = testing_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% testing_archived_v1 event tests
%% ===================================================================

testing_archived_v1_new_test() ->
    E = testing_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"div-1">>, testing_archived_v1:get_division_id(E)),
    ?assertEqual(<<"admin">>, testing_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, testing_archived_v1:get_reason(E)),
    ?assert(is_integer(testing_archived_v1:get_archived_at(E))).

testing_archived_v1_to_map_includes_event_type_test() ->
    E = testing_archived_v1:new(#{division_id => <<"d">>}),
    Map = testing_archived_v1:to_map(E),
    ?assertEqual(<<"testing_archived_v1">>, maps:get(<<"event_type">>, Map)).

testing_archived_v1_round_trip_test() ->
    E = testing_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>,
        archived_at => 12000
    }),
    Map = testing_archived_v1:to_map(E),
    {ok, E2} = testing_archived_v1:from_map(Map),
    ?assertEqual(testing_archived_v1:get_division_id(E),
                 testing_archived_v1:get_division_id(E2)),
    ?assertEqual(testing_archived_v1:get_archived_by(E),
                 testing_archived_v1:get_archived_by(E2)),
    ?assertEqual(testing_archived_v1:get_reason(E),
                 testing_archived_v1:get_reason(E2)),
    ?assertEqual(testing_archived_v1:get_archived_at(E),
                 testing_archived_v1:get_archived_at(E2)).

testing_archived_v1_defaults_test() ->
    E = testing_archived_v1:new(#{division_id => <<"d">>}),
    ?assertEqual(undefined, testing_archived_v1:get_archived_by(E)),
    ?assertEqual(undefined, testing_archived_v1:get_reason(E)).

testing_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = testing_archived_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = testing_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).
