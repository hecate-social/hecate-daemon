%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
%%% All 8 event modules for the monitor_division app.
-module(monitoring_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% monitoring_started_v1 event tests
%% ===================================================================

monitoring_started_v1_new_test() ->
    E = monitoring_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user">>
    }),
    ?assertEqual(<<"div-1">>, monitoring_started_v1:get_division_id(E)),
    ?assertEqual(<<"user">>, monitoring_started_v1:get_started_by(E)),
    ?assert(is_integer(monitoring_started_v1:get_started_at(E))).

monitoring_started_v1_to_map_includes_event_type_test() ->
    E = monitoring_started_v1:new(#{division_id => <<"d">>}),
    Map = monitoring_started_v1:to_map(E),
    ?assertEqual(<<"monitoring_started_v1">>, maps:get(<<"event_type">>, Map)).

monitoring_started_v1_round_trip_test() ->
    E = monitoring_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user">>,
        started_at => 5000
    }),
    Map = monitoring_started_v1:to_map(E),
    {ok, E2} = monitoring_started_v1:from_map(Map),
    ?assertEqual(monitoring_started_v1:get_division_id(E),
                 monitoring_started_v1:get_division_id(E2)),
    ?assertEqual(monitoring_started_v1:get_started_by(E),
                 monitoring_started_v1:get_started_by(E2)),
    ?assertEqual(monitoring_started_v1:get_started_at(E),
                 monitoring_started_v1:get_started_at(E2)).

monitoring_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = monitoring_started_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = monitoring_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% health_check_registered_v1 event tests
%% ===================================================================

health_check_registered_v1_new_test() ->
    E = health_check_registered_v1:new(#{
        division_id => <<"div-1">>,
        check_name => <<"api">>,
        check_type => <<"http">>,
        endpoint => <<"https://api.example.com/health">>,
        interval_ms => 15000
    }),
    ?assertEqual(<<"div-1">>, health_check_registered_v1:get_division_id(E)),
    ?assertEqual(<<"api">>, health_check_registered_v1:get_check_name(E)),
    ?assertEqual(<<"http">>, health_check_registered_v1:get_check_type(E)),
    ?assertEqual(<<"https://api.example.com/health">>, health_check_registered_v1:get_endpoint(E)),
    ?assertEqual(15000, health_check_registered_v1:get_interval_ms(E)),
    ?assert(is_binary(health_check_registered_v1:get_check_id(E))),
    ?assert(is_integer(health_check_registered_v1:get_registered_at(E))).

health_check_registered_v1_to_map_includes_event_type_test() ->
    E = health_check_registered_v1:new(#{division_id => <<"d">>, check_name => <<"c">>}),
    Map = health_check_registered_v1:to_map(E),
    ?assertEqual(<<"health_check_registered_v1">>, maps:get(<<"event_type">>, Map)).

health_check_registered_v1_round_trip_test() ->
    E = health_check_registered_v1:new(#{
        division_id => <<"div-1">>,
        check_name => <<"api">>,
        check_type => <<"http">>,
        endpoint => <<"https://api.example.com/health">>,
        interval_ms => 30000
    }),
    Map = health_check_registered_v1:to_map(E),
    {ok, E2} = health_check_registered_v1:from_map(Map),
    ?assertEqual(health_check_registered_v1:get_division_id(E),
                 health_check_registered_v1:get_division_id(E2)),
    ?assertEqual(health_check_registered_v1:get_check_id(E),
                 health_check_registered_v1:get_check_id(E2)),
    ?assertEqual(health_check_registered_v1:get_check_name(E),
                 health_check_registered_v1:get_check_name(E2)),
    ?assertEqual(health_check_registered_v1:get_check_type(E),
                 health_check_registered_v1:get_check_type(E2)),
    ?assertEqual(health_check_registered_v1:get_endpoint(E),
                 health_check_registered_v1:get_endpoint(E2)),
    ?assertEqual(health_check_registered_v1:get_interval_ms(E),
                 health_check_registered_v1:get_interval_ms(E2)),
    ?assertEqual(health_check_registered_v1:get_registered_at(E),
                 health_check_registered_v1:get_registered_at(E2)).

health_check_registered_v1_check_id_auto_generated_test() ->
    E = health_check_registered_v1:new(#{
        division_id => <<"div-1">>,
        check_name => <<"api">>
    }),
    ?assertEqual(<<"check-div-1-api">>, health_check_registered_v1:get_check_id(E)).

health_check_registered_v1_defaults_test() ->
    E = health_check_registered_v1:new(#{
        division_id => <<"div-1">>,
        check_name => <<"api">>
    }),
    ?assertEqual(<<"http">>, health_check_registered_v1:get_check_type(E)),
    ?assertEqual(<<>>, health_check_registered_v1:get_endpoint(E)),
    ?assertEqual(30000, health_check_registered_v1:get_interval_ms(E)).

%% ===================================================================
%% health_status_recorded_v1 event tests
%% ===================================================================

health_status_recorded_v1_new_test() ->
    E = health_status_recorded_v1:new(#{
        division_id => <<"div-1">>,
        check_id => <<"check-div-1-api">>,
        status => <<"healthy">>,
        latency_ms => 42,
        details => <<"200 OK">>
    }),
    ?assertEqual(<<"div-1">>, health_status_recorded_v1:get_division_id(E)),
    ?assertEqual(<<"check-div-1-api">>, health_status_recorded_v1:get_check_id(E)),
    ?assertEqual(<<"healthy">>, health_status_recorded_v1:get_status(E)),
    ?assertEqual(42, health_status_recorded_v1:get_latency_ms(E)),
    ?assertEqual(<<"200 OK">>, health_status_recorded_v1:get_details(E)),
    ?assert(is_integer(health_status_recorded_v1:get_recorded_at(E))).

health_status_recorded_v1_to_map_includes_event_type_test() ->
    E = health_status_recorded_v1:new(#{division_id => <<"d">>, check_id => <<"c">>}),
    Map = health_status_recorded_v1:to_map(E),
    ?assertEqual(<<"health_status_recorded_v1">>, maps:get(<<"event_type">>, Map)).

health_status_recorded_v1_round_trip_test() ->
    E = health_status_recorded_v1:new(#{
        division_id => <<"div-1">>,
        check_id => <<"check-div-1-api">>,
        status => <<"unhealthy">>,
        latency_ms => 5000,
        details => <<"timeout">>
    }),
    Map = health_status_recorded_v1:to_map(E),
    {ok, E2} = health_status_recorded_v1:from_map(Map),
    ?assertEqual(health_status_recorded_v1:get_division_id(E),
                 health_status_recorded_v1:get_division_id(E2)),
    ?assertEqual(health_status_recorded_v1:get_check_id(E),
                 health_status_recorded_v1:get_check_id(E2)),
    ?assertEqual(health_status_recorded_v1:get_status(E),
                 health_status_recorded_v1:get_status(E2)),
    ?assertEqual(health_status_recorded_v1:get_latency_ms(E),
                 health_status_recorded_v1:get_latency_ms(E2)),
    ?assertEqual(health_status_recorded_v1:get_details(E),
                 health_status_recorded_v1:get_details(E2)),
    ?assertEqual(health_status_recorded_v1:get_recorded_at(E),
                 health_status_recorded_v1:get_recorded_at(E2)).

health_status_recorded_v1_defaults_test() ->
    E = health_status_recorded_v1:new(#{
        division_id => <<"div-1">>,
        check_id => <<"c">>
    }),
    ?assertEqual(<<"unknown">>, health_status_recorded_v1:get_status(E)),
    ?assertEqual(0, health_status_recorded_v1:get_latency_ms(E)),
    ?assertEqual(undefined, health_status_recorded_v1:get_details(E)).

%% ===================================================================
%% incident_raised_v1 event tests
%% ===================================================================

incident_raised_v1_new_test() ->
    E = incident_raised_v1:new(#{
        division_id => <<"div-1">>,
        incident_title => <<"API Down">>,
        severity => <<"high">>,
        description => <<"Multiple failures">>
    }),
    ?assertEqual(<<"div-1">>, incident_raised_v1:get_division_id(E)),
    ?assertEqual(<<"API Down">>, incident_raised_v1:get_incident_title(E)),
    ?assertEqual(<<"high">>, incident_raised_v1:get_severity(E)),
    ?assertEqual(<<"Multiple failures">>, incident_raised_v1:get_description(E)),
    ?assert(is_binary(incident_raised_v1:get_incident_id(E))),
    ?assert(is_integer(incident_raised_v1:get_raised_at(E))).

incident_raised_v1_to_map_includes_event_type_test() ->
    E = incident_raised_v1:new(#{division_id => <<"d">>, incident_title => <<"T">>}),
    Map = incident_raised_v1:to_map(E),
    ?assertEqual(<<"incident_raised_v1">>, maps:get(<<"event_type">>, Map)).

incident_raised_v1_round_trip_test() ->
    E = incident_raised_v1:new(#{
        division_id => <<"div-1">>,
        incident_title => <<"DB Slow">>,
        severity => <<"medium">>,
        description => <<"Query latency > 5s">>
    }),
    Map = incident_raised_v1:to_map(E),
    {ok, E2} = incident_raised_v1:from_map(Map),
    ?assertEqual(incident_raised_v1:get_division_id(E),
                 incident_raised_v1:get_division_id(E2)),
    ?assertEqual(incident_raised_v1:get_incident_id(E),
                 incident_raised_v1:get_incident_id(E2)),
    ?assertEqual(incident_raised_v1:get_incident_title(E),
                 incident_raised_v1:get_incident_title(E2)),
    ?assertEqual(incident_raised_v1:get_severity(E),
                 incident_raised_v1:get_severity(E2)),
    ?assertEqual(incident_raised_v1:get_description(E),
                 incident_raised_v1:get_description(E2)),
    ?assertEqual(incident_raised_v1:get_raised_at(E),
                 incident_raised_v1:get_raised_at(E2)).

incident_raised_v1_defaults_test() ->
    E = incident_raised_v1:new(#{
        division_id => <<"div-1">>,
        incident_title => <<"Test">>
    }),
    ?assertEqual(<<"medium">>, incident_raised_v1:get_severity(E)),
    ?assertEqual(undefined, incident_raised_v1:get_description(E)).

incident_raised_v1_id_auto_generated_test() ->
    E = incident_raised_v1:new(#{
        division_id => <<"div-1">>,
        incident_title => <<"Test">>,
        raised_at => 9999
    }),
    ?assertEqual(<<"inc-div-1-9999">>, incident_raised_v1:get_incident_id(E)).

%% ===================================================================
%% monitoring_paused_v1 event tests
%% ===================================================================

monitoring_paused_v1_new_test() ->
    E = monitoring_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"maintenance">>
    }),
    ?assertEqual(<<"div-1">>, monitoring_paused_v1:get_division_id(E)),
    ?assertEqual(<<"maintenance">>, monitoring_paused_v1:get_reason(E)),
    ?assert(is_integer(monitoring_paused_v1:get_paused_at(E))).

monitoring_paused_v1_to_map_includes_event_type_test() ->
    E = monitoring_paused_v1:new(#{division_id => <<"d">>}),
    Map = monitoring_paused_v1:to_map(E),
    ?assertEqual(<<"monitoring_paused_v1">>, maps:get(<<"event_type">>, Map)).

monitoring_paused_v1_round_trip_test() ->
    E = monitoring_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"deploy">>,
        paused_at => 7000
    }),
    Map = monitoring_paused_v1:to_map(E),
    {ok, E2} = monitoring_paused_v1:from_map(Map),
    ?assertEqual(monitoring_paused_v1:get_division_id(E),
                 monitoring_paused_v1:get_division_id(E2)),
    ?assertEqual(monitoring_paused_v1:get_reason(E),
                 monitoring_paused_v1:get_reason(E2)),
    ?assertEqual(monitoring_paused_v1:get_paused_at(E),
                 monitoring_paused_v1:get_paused_at(E2)).

monitoring_paused_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = monitoring_paused_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = monitoring_paused_v1:get_paused_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% monitoring_resumed_v1 event tests
%% ===================================================================

monitoring_resumed_v1_new_test() ->
    E = monitoring_resumed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, monitoring_resumed_v1:get_division_id(E)),
    ?assert(is_integer(monitoring_resumed_v1:get_resumed_at(E))).

monitoring_resumed_v1_to_map_includes_event_type_test() ->
    E = monitoring_resumed_v1:new(#{division_id => <<"d">>}),
    Map = monitoring_resumed_v1:to_map(E),
    ?assertEqual(<<"monitoring_resumed_v1">>, maps:get(<<"event_type">>, Map)).

monitoring_resumed_v1_round_trip_test() ->
    E = monitoring_resumed_v1:new(#{
        division_id => <<"div-1">>,
        resumed_at => 8000
    }),
    Map = monitoring_resumed_v1:to_map(E),
    {ok, E2} = monitoring_resumed_v1:from_map(Map),
    ?assertEqual(monitoring_resumed_v1:get_division_id(E),
                 monitoring_resumed_v1:get_division_id(E2)),
    ?assertEqual(monitoring_resumed_v1:get_resumed_at(E),
                 monitoring_resumed_v1:get_resumed_at(E2)).

monitoring_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = monitoring_resumed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = monitoring_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% monitoring_completed_v1 event tests
%% ===================================================================

monitoring_completed_v1_new_test() ->
    E = monitoring_completed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, monitoring_completed_v1:get_division_id(E)),
    ?assert(is_integer(monitoring_completed_v1:get_completed_at(E))).

monitoring_completed_v1_to_map_includes_event_type_test() ->
    E = monitoring_completed_v1:new(#{division_id => <<"d">>}),
    Map = monitoring_completed_v1:to_map(E),
    ?assertEqual(<<"monitoring_completed_v1">>, maps:get(<<"event_type">>, Map)).

monitoring_completed_v1_round_trip_test() ->
    E = monitoring_completed_v1:new(#{
        division_id => <<"div-1">>,
        completed_at => 9000
    }),
    Map = monitoring_completed_v1:to_map(E),
    {ok, E2} = monitoring_completed_v1:from_map(Map),
    ?assertEqual(monitoring_completed_v1:get_division_id(E),
                 monitoring_completed_v1:get_division_id(E2)),
    ?assertEqual(monitoring_completed_v1:get_completed_at(E),
                 monitoring_completed_v1:get_completed_at(E2)).

monitoring_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = monitoring_completed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = monitoring_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% monitoring_archived_v1 event tests
%% ===================================================================

monitoring_archived_v1_new_test() ->
    E = monitoring_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"div-1">>, monitoring_archived_v1:get_division_id(E)),
    ?assertEqual(<<"admin">>, monitoring_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, monitoring_archived_v1:get_reason(E)),
    ?assert(is_integer(monitoring_archived_v1:get_archived_at(E))).

monitoring_archived_v1_to_map_includes_event_type_test() ->
    E = monitoring_archived_v1:new(#{division_id => <<"d">>}),
    Map = monitoring_archived_v1:to_map(E),
    ?assertEqual(<<"monitoring_archived_v1">>, maps:get(<<"event_type">>, Map)).

monitoring_archived_v1_round_trip_test() ->
    E = monitoring_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>,
        archived_at => 10000
    }),
    Map = monitoring_archived_v1:to_map(E),
    {ok, E2} = monitoring_archived_v1:from_map(Map),
    ?assertEqual(monitoring_archived_v1:get_division_id(E),
                 monitoring_archived_v1:get_division_id(E2)),
    ?assertEqual(monitoring_archived_v1:get_archived_by(E),
                 monitoring_archived_v1:get_archived_by(E2)),
    ?assertEqual(monitoring_archived_v1:get_reason(E),
                 monitoring_archived_v1:get_reason(E2)),
    ?assertEqual(monitoring_archived_v1:get_archived_at(E),
                 monitoring_archived_v1:get_archived_at(E2)).

monitoring_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = monitoring_archived_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = monitoring_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

monitoring_archived_v1_defaults_test() ->
    E = monitoring_archived_v1:new(#{division_id => <<"div-1">>}),
    ?assertEqual(undefined, monitoring_archived_v1:get_archived_by(E)),
    ?assertEqual(undefined, monitoring_archived_v1:get_reason(E)).
