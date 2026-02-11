%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
-module(generation_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% generation_started_v1 event tests
%% ===================================================================

generation_started_v1_new_test() ->
    E = generation_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user">>
    }),
    ?assertEqual(<<"div-1">>, generation_started_v1:get_division_id(E)),
    ?assertEqual(<<"user">>, generation_started_v1:get_started_by(E)),
    ?assert(is_integer(generation_started_v1:get_started_at(E))).

generation_started_v1_to_map_includes_event_type_test() ->
    E = generation_started_v1:new(#{division_id => <<"d">>}),
    Map = generation_started_v1:to_map(E),
    ?assertEqual(<<"generation_started_v1">>, maps:get(<<"event_type">>, Map)).

generation_started_v1_round_trip_test() ->
    E = generation_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user">>,
        started_at => 1000
    }),
    Map = generation_started_v1:to_map(E),
    {ok, E2} = generation_started_v1:from_map(Map),
    ?assertEqual(generation_started_v1:get_division_id(E),
                 generation_started_v1:get_division_id(E2)),
    ?assertEqual(generation_started_v1:get_started_at(E),
                 generation_started_v1:get_started_at(E2)),
    ?assertEqual(generation_started_v1:get_started_by(E),
                 generation_started_v1:get_started_by(E2)).

generation_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = generation_started_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = generation_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% module_generated_v1 event tests
%% ===================================================================

module_generated_v1_new_test() ->
    E = module_generated_v1:new(#{
        division_id => <<"div-1">>,
        module_name => <<"my_mod">>,
        module_type => <<"command">>,
        file_path => <<"src/my_mod.erl">>,
        content => <<"-module(my_mod).">>,
        description => <<"A module">>,
        generated_by => <<"hecate">>
    }),
    ?assertEqual(<<"div-1">>, module_generated_v1:get_division_id(E)),
    ?assertEqual(<<"my_mod">>, module_generated_v1:get_module_name(E)),
    ?assertEqual(<<"command">>, module_generated_v1:get_module_type(E)),
    ?assertEqual(<<"src/my_mod.erl">>, module_generated_v1:get_file_path(E)),
    ?assertEqual(<<"-module(my_mod).">>, module_generated_v1:get_content(E)),
    ?assertEqual(<<"A module">>, module_generated_v1:get_description(E)),
    ?assertEqual(<<"hecate">>, module_generated_v1:get_generated_by(E)),
    ?assert(is_binary(module_generated_v1:get_module_id(E))),
    ?assert(is_integer(module_generated_v1:get_generated_at(E))).

module_generated_v1_to_map_includes_event_type_test() ->
    E = module_generated_v1:new(#{division_id => <<"d">>, module_name => <<"m">>}),
    Map = module_generated_v1:to_map(E),
    ?assertEqual(<<"module_generated_v1">>, maps:get(<<"event_type">>, Map)).

module_generated_v1_round_trip_test() ->
    E = module_generated_v1:new(#{
        division_id => <<"div-1">>,
        module_name => <<"my_mod">>,
        module_type => <<"handler">>,
        file_path => <<"src/my_mod.erl">>,
        content => <<"content">>,
        description => <<"desc">>,
        generated_by => <<"agent">>,
        generated_at => 5000
    }),
    Map = module_generated_v1:to_map(E),
    {ok, E2} = module_generated_v1:from_map(Map),
    ?assertEqual(module_generated_v1:get_division_id(E),
                 module_generated_v1:get_division_id(E2)),
    ?assertEqual(module_generated_v1:get_module_name(E),
                 module_generated_v1:get_module_name(E2)),
    ?assertEqual(module_generated_v1:get_module_type(E),
                 module_generated_v1:get_module_type(E2)),
    ?assertEqual(module_generated_v1:get_file_path(E),
                 module_generated_v1:get_file_path(E2)),
    ?assertEqual(module_generated_v1:get_content(E),
                 module_generated_v1:get_content(E2)),
    ?assertEqual(module_generated_v1:get_generated_at(E),
                 module_generated_v1:get_generated_at(E2)).

module_generated_v1_auto_id_test() ->
    E = module_generated_v1:new(#{division_id => <<"d">>, module_name => <<"m">>}),
    Id = module_generated_v1:get_module_id(E),
    ?assert(is_binary(Id)),
    ?assertMatch(<<"mod-", _/binary>>, Id).

module_generated_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = module_generated_v1:new(#{division_id => <<"d">>, module_name => <<"m">>}),
    After = erlang:system_time(millisecond),
    T = module_generated_v1:get_generated_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% test_generated_v1 event tests
%% ===================================================================

test_generated_v1_new_test() ->
    E = test_generated_v1:new(#{
        division_id => <<"div-1">>,
        test_name => <<"my_tests">>,
        test_type => <<"unit">>,
        module_name => <<"my_mod">>,
        file_path => <<"test/my_tests.erl">>,
        content => <<"-module(my_tests).">>,
        description => <<"Tests">>,
        generated_by => <<"hecate">>
    }),
    ?assertEqual(<<"div-1">>, test_generated_v1:get_division_id(E)),
    ?assertEqual(<<"my_tests">>, test_generated_v1:get_test_name(E)),
    ?assertEqual(<<"unit">>, test_generated_v1:get_test_type(E)),
    ?assertEqual(<<"my_mod">>, test_generated_v1:get_module_name(E)),
    ?assertEqual(<<"test/my_tests.erl">>, test_generated_v1:get_file_path(E)),
    ?assertEqual(<<"-module(my_tests).">>, test_generated_v1:get_content(E)),
    ?assertEqual(<<"Tests">>, test_generated_v1:get_description(E)),
    ?assertEqual(<<"hecate">>, test_generated_v1:get_generated_by(E)),
    ?assert(is_binary(test_generated_v1:get_test_id(E))),
    ?assert(is_integer(test_generated_v1:get_generated_at(E))).

test_generated_v1_to_map_includes_event_type_test() ->
    E = test_generated_v1:new(#{division_id => <<"d">>, test_name => <<"t">>}),
    Map = test_generated_v1:to_map(E),
    ?assertEqual(<<"test_generated_v1">>, maps:get(<<"event_type">>, Map)).

test_generated_v1_round_trip_test() ->
    E = test_generated_v1:new(#{
        division_id => <<"div-1">>,
        test_name => <<"my_tests">>,
        test_type => <<"integration">>,
        module_name => <<"my_mod">>,
        file_path => <<"test/my_tests.erl">>,
        content => <<"test content">>,
        description => <<"desc">>,
        generated_by => <<"agent">>,
        generated_at => 7000
    }),
    Map = test_generated_v1:to_map(E),
    {ok, E2} = test_generated_v1:from_map(Map),
    ?assertEqual(test_generated_v1:get_division_id(E),
                 test_generated_v1:get_division_id(E2)),
    ?assertEqual(test_generated_v1:get_test_name(E),
                 test_generated_v1:get_test_name(E2)),
    ?assertEqual(test_generated_v1:get_test_type(E),
                 test_generated_v1:get_test_type(E2)),
    ?assertEqual(test_generated_v1:get_module_name(E),
                 test_generated_v1:get_module_name(E2)),
    ?assertEqual(test_generated_v1:get_content(E),
                 test_generated_v1:get_content(E2)),
    ?assertEqual(test_generated_v1:get_generated_at(E),
                 test_generated_v1:get_generated_at(E2)).

test_generated_v1_auto_id_test() ->
    E = test_generated_v1:new(#{division_id => <<"d">>, test_name => <<"t">>}),
    Id = test_generated_v1:get_test_id(E),
    ?assert(is_binary(Id)),
    ?assertMatch(<<"tst-", _/binary>>, Id).

test_generated_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = test_generated_v1:new(#{division_id => <<"d">>, test_name => <<"t">>}),
    After = erlang:system_time(millisecond),
    T = test_generated_v1:get_generated_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% generation_paused_v1 event tests
%% ===================================================================

generation_paused_v1_new_test() ->
    E = generation_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"need review">>
    }),
    ?assertEqual(<<"div-1">>, generation_paused_v1:get_division_id(E)),
    ?assertEqual(<<"need review">>, generation_paused_v1:get_reason(E)),
    ?assert(is_integer(generation_paused_v1:get_paused_at(E))).

generation_paused_v1_to_map_includes_event_type_test() ->
    E = generation_paused_v1:new(#{division_id => <<"d">>}),
    Map = generation_paused_v1:to_map(E),
    ?assertEqual(<<"generation_paused_v1">>, maps:get(<<"event_type">>, Map)).

generation_paused_v1_round_trip_test() ->
    E = generation_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"blocked">>,
        paused_at => 4000
    }),
    Map = generation_paused_v1:to_map(E),
    {ok, E2} = generation_paused_v1:from_map(Map),
    ?assertEqual(generation_paused_v1:get_division_id(E),
                 generation_paused_v1:get_division_id(E2)),
    ?assertEqual(generation_paused_v1:get_paused_at(E),
                 generation_paused_v1:get_paused_at(E2)),
    ?assertEqual(generation_paused_v1:get_reason(E),
                 generation_paused_v1:get_reason(E2)).

generation_paused_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = generation_paused_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = generation_paused_v1:get_paused_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% generation_resumed_v1 event tests
%% ===================================================================

generation_resumed_v1_new_test() ->
    E = generation_resumed_v1:new(#{division_id => <<"div-1">>}),
    ?assertEqual(<<"div-1">>, generation_resumed_v1:get_division_id(E)),
    ?assert(is_integer(generation_resumed_v1:get_resumed_at(E))).

generation_resumed_v1_to_map_includes_event_type_test() ->
    E = generation_resumed_v1:new(#{division_id => <<"d">>}),
    Map = generation_resumed_v1:to_map(E),
    ?assertEqual(<<"generation_resumed_v1">>, maps:get(<<"event_type">>, Map)).

generation_resumed_v1_round_trip_test() ->
    E = generation_resumed_v1:new(#{
        division_id => <<"div-1">>,
        resumed_at => 5000
    }),
    Map = generation_resumed_v1:to_map(E),
    {ok, E2} = generation_resumed_v1:from_map(Map),
    ?assertEqual(generation_resumed_v1:get_division_id(E),
                 generation_resumed_v1:get_division_id(E2)),
    ?assertEqual(generation_resumed_v1:get_resumed_at(E),
                 generation_resumed_v1:get_resumed_at(E2)).

generation_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = generation_resumed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = generation_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% generation_completed_v1 event tests
%% ===================================================================

generation_completed_v1_new_test() ->
    E = generation_completed_v1:new(#{division_id => <<"div-1">>}),
    ?assertEqual(<<"div-1">>, generation_completed_v1:get_division_id(E)),
    ?assert(is_integer(generation_completed_v1:get_completed_at(E))).

generation_completed_v1_to_map_includes_event_type_test() ->
    E = generation_completed_v1:new(#{division_id => <<"d">>}),
    Map = generation_completed_v1:to_map(E),
    ?assertEqual(<<"generation_completed_v1">>, maps:get(<<"event_type">>, Map)).

generation_completed_v1_round_trip_test() ->
    E = generation_completed_v1:new(#{
        division_id => <<"div-1">>,
        completed_at => 6000
    }),
    Map = generation_completed_v1:to_map(E),
    {ok, E2} = generation_completed_v1:from_map(Map),
    ?assertEqual(generation_completed_v1:get_division_id(E),
                 generation_completed_v1:get_division_id(E2)),
    ?assertEqual(generation_completed_v1:get_completed_at(E),
                 generation_completed_v1:get_completed_at(E2)).

generation_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = generation_completed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = generation_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% generation_archived_v1 event tests
%% ===================================================================

generation_archived_v1_new_test() ->
    E = generation_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"div-1">>, generation_archived_v1:get_division_id(E)),
    ?assertEqual(<<"admin">>, generation_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, generation_archived_v1:get_reason(E)),
    ?assert(is_integer(generation_archived_v1:get_archived_at(E))).

generation_archived_v1_to_map_includes_event_type_test() ->
    E = generation_archived_v1:new(#{division_id => <<"d">>}),
    Map = generation_archived_v1:to_map(E),
    ?assertEqual(<<"generation_archived_v1">>, maps:get(<<"event_type">>, Map)).

generation_archived_v1_round_trip_test() ->
    E = generation_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>,
        archived_at => 7000
    }),
    Map = generation_archived_v1:to_map(E),
    {ok, E2} = generation_archived_v1:from_map(Map),
    ?assertEqual(generation_archived_v1:get_division_id(E),
                 generation_archived_v1:get_division_id(E2)),
    ?assertEqual(generation_archived_v1:get_archived_at(E),
                 generation_archived_v1:get_archived_at(E2)),
    ?assertEqual(generation_archived_v1:get_archived_by(E),
                 generation_archived_v1:get_archived_by(E2)),
    ?assertEqual(generation_archived_v1:get_reason(E),
                 generation_archived_v1:get_reason(E2)).

generation_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = generation_archived_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = generation_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).
