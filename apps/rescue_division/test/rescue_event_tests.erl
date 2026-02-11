%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
-module(rescue_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% rescue_started_v1 event tests
%% ===================================================================

rescue_started_v1_new_test() ->
    E = rescue_started_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        started_by => <<"user">>
    }),
    ?assertEqual(<<"div-1">>, rescue_started_v1:get_division_id(E)),
    ?assertEqual(<<"inc-1">>, rescue_started_v1:get_incident_id(E)),
    ?assertEqual(<<"user">>, rescue_started_v1:get_started_by(E)),
    ?assert(is_integer(rescue_started_v1:get_started_at(E))).

rescue_started_v1_to_map_includes_event_type_test() ->
    E = rescue_started_v1:new(#{division_id => <<"d">>, incident_id => <<"i">>}),
    Map = rescue_started_v1:to_map(E),
    ?assertEqual(<<"rescue_started_v1">>, maps:get(<<"event_type">>, Map)).

rescue_started_v1_round_trip_test() ->
    E = rescue_started_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        started_by => <<"user">>
    }),
    Map = rescue_started_v1:to_map(E),
    {ok, E2} = rescue_started_v1:from_map(Map),
    ?assertEqual(rescue_started_v1:get_division_id(E), rescue_started_v1:get_division_id(E2)),
    ?assertEqual(rescue_started_v1:get_incident_id(E), rescue_started_v1:get_incident_id(E2)),
    ?assertEqual(rescue_started_v1:get_started_at(E), rescue_started_v1:get_started_at(E2)),
    ?assertEqual(rescue_started_v1:get_started_by(E), rescue_started_v1:get_started_by(E2)).

rescue_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = rescue_started_v1:new(#{division_id => <<"d">>, incident_id => <<"i">>}),
    After = erlang:system_time(millisecond),
    T = rescue_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% incident_diagnosed_v1 event tests
%% ===================================================================

incident_diagnosed_v1_new_test() ->
    E = incident_diagnosed_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        diagnosis => <<"Memory leak">>,
        root_cause => <<"Unbounded queue">>,
        diagnosed_by => <<"eng">>
    }),
    ?assertEqual(<<"div-1">>, incident_diagnosed_v1:get_division_id(E)),
    ?assertEqual(<<"inc-1">>, incident_diagnosed_v1:get_incident_id(E)),
    ?assertEqual(<<"Memory leak">>, incident_diagnosed_v1:get_diagnosis(E)),
    ?assertEqual(<<"Unbounded queue">>, incident_diagnosed_v1:get_root_cause(E)),
    ?assertEqual(<<"eng">>, incident_diagnosed_v1:get_diagnosed_by(E)),
    ?assert(is_binary(incident_diagnosed_v1:get_diagnosis_id(E))),
    ?assert(is_integer(incident_diagnosed_v1:get_diagnosed_at(E))).

incident_diagnosed_v1_to_map_includes_event_type_test() ->
    E = incident_diagnosed_v1:new(#{
        division_id => <<"d">>, incident_id => <<"i">>,
        diagnosis => <<"x">>, root_cause => <<"y">>
    }),
    Map = incident_diagnosed_v1:to_map(E),
    ?assertEqual(<<"incident_diagnosed_v1">>, maps:get(<<"event_type">>, Map)).

incident_diagnosed_v1_round_trip_test() ->
    E = incident_diagnosed_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        diagnosis => <<"Crash loop">>,
        root_cause => <<"OOM">>,
        diagnosed_by => <<"eng">>
    }),
    Map = incident_diagnosed_v1:to_map(E),
    {ok, E2} = incident_diagnosed_v1:from_map(Map),
    ?assertEqual(incident_diagnosed_v1:get_division_id(E), incident_diagnosed_v1:get_division_id(E2)),
    ?assertEqual(incident_diagnosed_v1:get_diagnosis_id(E), incident_diagnosed_v1:get_diagnosis_id(E2)),
    ?assertEqual(incident_diagnosed_v1:get_incident_id(E), incident_diagnosed_v1:get_incident_id(E2)),
    ?assertEqual(incident_diagnosed_v1:get_diagnosis(E), incident_diagnosed_v1:get_diagnosis(E2)),
    ?assertEqual(incident_diagnosed_v1:get_root_cause(E), incident_diagnosed_v1:get_root_cause(E2)),
    ?assertEqual(incident_diagnosed_v1:get_diagnosed_by(E), incident_diagnosed_v1:get_diagnosed_by(E2)),
    ?assertEqual(incident_diagnosed_v1:get_diagnosed_at(E), incident_diagnosed_v1:get_diagnosed_at(E2)).

incident_diagnosed_v1_auto_generates_diagnosis_id_test() ->
    E = incident_diagnosed_v1:new(#{
        division_id => <<"d">>, incident_id => <<"inc-x">>,
        diagnosis => <<"x">>, root_cause => <<"y">>
    }),
    DiagId = incident_diagnosed_v1:get_diagnosis_id(E),
    ?assert(is_binary(DiagId)),
    %% Auto-generated ID starts with "diag-"
    ?assertMatch(<<"diag-", _/binary>>, DiagId).

incident_diagnosed_v1_custom_diagnosis_id_test() ->
    E = incident_diagnosed_v1:new(#{
        division_id => <<"d">>, incident_id => <<"i">>,
        diagnosis => <<"x">>, root_cause => <<"y">>,
        diagnosis_id => <<"custom-diag-42">>
    }),
    ?assertEqual(<<"custom-diag-42">>, incident_diagnosed_v1:get_diagnosis_id(E)).

%% ===================================================================
%% fix_applied_v1 event tests
%% ===================================================================

fix_applied_v1_new_test() ->
    E = fix_applied_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        diagnosis_id => <<"diag-1">>,
        fix_description => <<"Added rate limiter">>,
        fix_type => <<"hotfix">>,
        applied_by => <<"eng">>
    }),
    ?assertEqual(<<"div-1">>, fix_applied_v1:get_division_id(E)),
    ?assertEqual(<<"inc-1">>, fix_applied_v1:get_incident_id(E)),
    ?assertEqual(<<"diag-1">>, fix_applied_v1:get_diagnosis_id(E)),
    ?assertEqual(<<"Added rate limiter">>, fix_applied_v1:get_fix_description(E)),
    ?assertEqual(<<"hotfix">>, fix_applied_v1:get_fix_type(E)),
    ?assertEqual(<<"eng">>, fix_applied_v1:get_applied_by(E)),
    ?assert(is_binary(fix_applied_v1:get_fix_id(E))),
    ?assert(is_integer(fix_applied_v1:get_applied_at(E))).

fix_applied_v1_to_map_includes_event_type_test() ->
    E = fix_applied_v1:new(#{
        division_id => <<"d">>, incident_id => <<"i">>,
        diagnosis_id => <<"dg">>, fix_description => <<"f">>,
        fix_type => <<"t">>
    }),
    Map = fix_applied_v1:to_map(E),
    ?assertEqual(<<"fix_applied_v1">>, maps:get(<<"event_type">>, Map)).

fix_applied_v1_round_trip_test() ->
    E = fix_applied_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        diagnosis_id => <<"diag-1">>,
        fix_description => <<"Patched">>,
        fix_type => <<"patch">>,
        applied_by => <<"eng">>
    }),
    Map = fix_applied_v1:to_map(E),
    {ok, E2} = fix_applied_v1:from_map(Map),
    ?assertEqual(fix_applied_v1:get_division_id(E), fix_applied_v1:get_division_id(E2)),
    ?assertEqual(fix_applied_v1:get_fix_id(E), fix_applied_v1:get_fix_id(E2)),
    ?assertEqual(fix_applied_v1:get_incident_id(E), fix_applied_v1:get_incident_id(E2)),
    ?assertEqual(fix_applied_v1:get_diagnosis_id(E), fix_applied_v1:get_diagnosis_id(E2)),
    ?assertEqual(fix_applied_v1:get_fix_description(E), fix_applied_v1:get_fix_description(E2)),
    ?assertEqual(fix_applied_v1:get_fix_type(E), fix_applied_v1:get_fix_type(E2)),
    ?assertEqual(fix_applied_v1:get_applied_by(E), fix_applied_v1:get_applied_by(E2)),
    ?assertEqual(fix_applied_v1:get_applied_at(E), fix_applied_v1:get_applied_at(E2)).

fix_applied_v1_auto_generates_fix_id_test() ->
    E = fix_applied_v1:new(#{
        division_id => <<"d">>, incident_id => <<"inc-x">>,
        diagnosis_id => <<"dg">>, fix_description => <<"f">>,
        fix_type => <<"t">>
    }),
    FixId = fix_applied_v1:get_fix_id(E),
    ?assert(is_binary(FixId)),
    ?assertMatch(<<"fix-", _/binary>>, FixId).

fix_applied_v1_custom_fix_id_test() ->
    E = fix_applied_v1:new(#{
        division_id => <<"d">>, incident_id => <<"i">>,
        diagnosis_id => <<"dg">>, fix_description => <<"f">>,
        fix_type => <<"t">>, fix_id => <<"custom-fix-99">>
    }),
    ?assertEqual(<<"custom-fix-99">>, fix_applied_v1:get_fix_id(E)).

%% ===================================================================
%% rescue_paused_v1 event tests
%% ===================================================================

rescue_paused_v1_new_test() ->
    E = rescue_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"Blocked on upstream">>
    }),
    ?assertEqual(<<"div-1">>, rescue_paused_v1:get_division_id(E)),
    ?assertEqual(<<"Blocked on upstream">>, rescue_paused_v1:get_reason(E)),
    ?assert(is_integer(rescue_paused_v1:get_paused_at(E))).

rescue_paused_v1_to_map_includes_event_type_test() ->
    E = rescue_paused_v1:new(#{division_id => <<"d">>}),
    Map = rescue_paused_v1:to_map(E),
    ?assertEqual(<<"rescue_paused_v1">>, maps:get(<<"event_type">>, Map)).

rescue_paused_v1_round_trip_test() ->
    E = rescue_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"review">>
    }),
    Map = rescue_paused_v1:to_map(E),
    {ok, E2} = rescue_paused_v1:from_map(Map),
    ?assertEqual(rescue_paused_v1:get_division_id(E), rescue_paused_v1:get_division_id(E2)),
    ?assertEqual(rescue_paused_v1:get_paused_at(E), rescue_paused_v1:get_paused_at(E2)),
    ?assertEqual(rescue_paused_v1:get_reason(E), rescue_paused_v1:get_reason(E2)).

rescue_paused_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = rescue_paused_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = rescue_paused_v1:get_paused_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% rescue_resumed_v1 event tests
%% ===================================================================

rescue_resumed_v1_new_test() ->
    E = rescue_resumed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, rescue_resumed_v1:get_division_id(E)),
    ?assert(is_integer(rescue_resumed_v1:get_resumed_at(E))).

rescue_resumed_v1_to_map_includes_event_type_test() ->
    E = rescue_resumed_v1:new(#{division_id => <<"d">>}),
    Map = rescue_resumed_v1:to_map(E),
    ?assertEqual(<<"rescue_resumed_v1">>, maps:get(<<"event_type">>, Map)).

rescue_resumed_v1_round_trip_test() ->
    E = rescue_resumed_v1:new(#{
        division_id => <<"div-1">>
    }),
    Map = rescue_resumed_v1:to_map(E),
    {ok, E2} = rescue_resumed_v1:from_map(Map),
    ?assertEqual(rescue_resumed_v1:get_division_id(E), rescue_resumed_v1:get_division_id(E2)),
    ?assertEqual(rescue_resumed_v1:get_resumed_at(E), rescue_resumed_v1:get_resumed_at(E2)).

rescue_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = rescue_resumed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = rescue_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% rescue_completed_v1 event tests
%% ===================================================================

rescue_completed_v1_new_test() ->
    E = rescue_completed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, rescue_completed_v1:get_division_id(E)),
    ?assert(is_integer(rescue_completed_v1:get_completed_at(E))).

rescue_completed_v1_to_map_includes_event_type_test() ->
    E = rescue_completed_v1:new(#{division_id => <<"d">>}),
    Map = rescue_completed_v1:to_map(E),
    ?assertEqual(<<"rescue_completed_v1">>, maps:get(<<"event_type">>, Map)).

rescue_completed_v1_round_trip_test() ->
    E = rescue_completed_v1:new(#{
        division_id => <<"div-1">>
    }),
    Map = rescue_completed_v1:to_map(E),
    {ok, E2} = rescue_completed_v1:from_map(Map),
    ?assertEqual(rescue_completed_v1:get_division_id(E), rescue_completed_v1:get_division_id(E2)),
    ?assertEqual(rescue_completed_v1:get_completed_at(E), rescue_completed_v1:get_completed_at(E2)).

rescue_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = rescue_completed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = rescue_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% rescue_archived_v1 event tests
%% ===================================================================

rescue_archived_v1_new_test() ->
    E = rescue_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"div-1">>, rescue_archived_v1:get_division_id(E)),
    ?assertEqual(<<"admin">>, rescue_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, rescue_archived_v1:get_reason(E)),
    ?assert(is_integer(rescue_archived_v1:get_archived_at(E))).

rescue_archived_v1_to_map_includes_event_type_test() ->
    E = rescue_archived_v1:new(#{division_id => <<"d">>}),
    Map = rescue_archived_v1:to_map(E),
    ?assertEqual(<<"rescue_archived_v1">>, maps:get(<<"event_type">>, Map)).

rescue_archived_v1_round_trip_test() ->
    E = rescue_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    Map = rescue_archived_v1:to_map(E),
    {ok, E2} = rescue_archived_v1:from_map(Map),
    ?assertEqual(rescue_archived_v1:get_division_id(E), rescue_archived_v1:get_division_id(E2)),
    ?assertEqual(rescue_archived_v1:get_archived_at(E), rescue_archived_v1:get_archived_at(E2)),
    ?assertEqual(rescue_archived_v1:get_archived_by(E), rescue_archived_v1:get_archived_by(E2)),
    ?assertEqual(rescue_archived_v1:get_reason(E), rescue_archived_v1:get_reason(E2)).

rescue_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = rescue_archived_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = rescue_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).
