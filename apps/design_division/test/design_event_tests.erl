%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
-module(design_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% design_started_v1 event tests
%% ===================================================================

design_started_v1_new_test() ->
    E = design_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    ?assertEqual(<<"div-1">>, design_started_v1:get_division_id(E)),
    ?assertEqual(<<"user@host">>, design_started_v1:get_started_by(E)),
    ?assert(is_integer(design_started_v1:get_started_at(E))).

design_started_v1_to_map_includes_event_type_test() ->
    E = design_started_v1:new(#{division_id => <<"div-1">>}),
    Map = design_started_v1:to_map(E),
    ?assertEqual(<<"design_started_v1">>, maps:get(<<"event_type">>, Map)).

design_started_v1_round_trip_test() ->
    E = design_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    Map = design_started_v1:to_map(E),
    {ok, E2} = design_started_v1:from_map(Map),
    ?assertEqual(design_started_v1:get_division_id(E),
                 design_started_v1:get_division_id(E2)),
    ?assertEqual(design_started_v1:get_started_at(E),
                 design_started_v1:get_started_at(E2)),
    ?assertEqual(design_started_v1:get_started_by(E),
                 design_started_v1:get_started_by(E2)).

design_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = design_started_v1:new(#{division_id => <<"div-1">>}),
    After = erlang:system_time(millisecond),
    T = design_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

design_started_v1_explicit_timestamp_test() ->
    E = design_started_v1:new(#{division_id => <<"div-1">>, started_at => 42000}),
    ?assertEqual(42000, design_started_v1:get_started_at(E)).

design_started_v1_to_map_all_fields_test() ->
    E = design_started_v1:new(#{
        division_id => <<"div-1">>,
        started_at => 1000,
        started_by => <<"user">>
    }),
    Map = design_started_v1:to_map(E),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(1000, maps:get(<<"started_at">>, Map)),
    ?assertEqual(<<"user">>, maps:get(<<"started_by">>, Map)),
    ?assertEqual(<<"design_started_v1">>, maps:get(<<"event_type">>, Map)).

%% ===================================================================
%% aggregate_designed_v1 event tests
%% ===================================================================

aggregate_designed_v1_new_test() ->
    E = aggregate_designed_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"order_aggregate">>,
        stream_pattern => <<"order-{id}">>,
        status_flags => [#{<<"name">> => <<"active">>}],
        description => <<"Manages orders">>,
        designed_by => <<"architect">>
    }),
    ?assertEqual(<<"div-1">>, aggregate_designed_v1:get_division_id(E)),
    ?assertEqual(<<"order_aggregate">>, aggregate_designed_v1:get_aggregate_name(E)),
    ?assertEqual(<<"order-{id}">>, aggregate_designed_v1:get_stream_pattern(E)),
    ?assertEqual([#{<<"name">> => <<"active">>}], aggregate_designed_v1:get_status_flags(E)),
    ?assertEqual(<<"Manages orders">>, aggregate_designed_v1:get_description(E)),
    ?assertEqual(<<"architect">>, aggregate_designed_v1:get_designed_by(E)),
    ?assert(is_integer(aggregate_designed_v1:get_designed_at(E))).

aggregate_designed_v1_auto_id_test() ->
    E = aggregate_designed_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"agg">>
    }),
    AggId = aggregate_designed_v1:get_aggregate_id(E),
    ?assert(is_binary(AggId)),
    ?assertMatch(<<"agg-", _/binary>>, AggId).

aggregate_designed_v1_to_map_includes_event_type_test() ->
    E = aggregate_designed_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"agg">>
    }),
    Map = aggregate_designed_v1:to_map(E),
    ?assertEqual(<<"aggregate_designed_v1">>, maps:get(<<"event_type">>, Map)).

aggregate_designed_v1_round_trip_test() ->
    E = aggregate_designed_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"order_aggregate">>,
        stream_pattern => <<"order-{id}">>,
        description => <<"Manages orders">>,
        designed_by => <<"architect">>
    }),
    Map = aggregate_designed_v1:to_map(E),
    {ok, E2} = aggregate_designed_v1:from_map(Map),
    ?assertEqual(aggregate_designed_v1:get_division_id(E),
                 aggregate_designed_v1:get_division_id(E2)),
    ?assertEqual(aggregate_designed_v1:get_aggregate_id(E),
                 aggregate_designed_v1:get_aggregate_id(E2)),
    ?assertEqual(aggregate_designed_v1:get_aggregate_name(E),
                 aggregate_designed_v1:get_aggregate_name(E2)),
    ?assertEqual(aggregate_designed_v1:get_stream_pattern(E),
                 aggregate_designed_v1:get_stream_pattern(E2)),
    ?assertEqual(aggregate_designed_v1:get_description(E),
                 aggregate_designed_v1:get_description(E2)),
    ?assertEqual(aggregate_designed_v1:get_designed_by(E),
                 aggregate_designed_v1:get_designed_by(E2)),
    ?assertEqual(aggregate_designed_v1:get_designed_at(E),
                 aggregate_designed_v1:get_designed_at(E2)).

aggregate_designed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = aggregate_designed_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"agg">>
    }),
    After = erlang:system_time(millisecond),
    T = aggregate_designed_v1:get_designed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

aggregate_designed_v1_to_map_all_fields_test() ->
    E = aggregate_designed_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_id => <<"agg-explicit">>,
        aggregate_name => <<"order_aggregate">>,
        stream_pattern => <<"order-{id}">>,
        status_flags => [#{<<"bit">> => 1}],
        description => <<"Desc">>,
        designed_by => <<"arch">>,
        designed_at => 5000
    }),
    Map = aggregate_designed_v1:to_map(E),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"agg-explicit">>, maps:get(<<"aggregate_id">>, Map)),
    ?assertEqual(<<"order_aggregate">>, maps:get(<<"aggregate_name">>, Map)),
    ?assertEqual(<<"order-{id}">>, maps:get(<<"stream_pattern">>, Map)),
    ?assertEqual([#{<<"bit">> => 1}], maps:get(<<"status_flags">>, Map)),
    ?assertEqual(<<"Desc">>, maps:get(<<"description">>, Map)),
    ?assertEqual(<<"arch">>, maps:get(<<"designed_by">>, Map)),
    ?assertEqual(5000, maps:get(<<"designed_at">>, Map)).

%% ===================================================================
%% event_designed_v1 event tests
%% ===================================================================

event_designed_v1_new_test() ->
    E = event_designed_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        aggregate_name => <<"order_aggregate">>,
        payload_fields => [#{<<"name">> => <<"order_id">>}],
        description => <<"Order was placed">>,
        designed_by => <<"architect">>
    }),
    ?assertEqual(<<"div-1">>, event_designed_v1:get_division_id(E)),
    ?assertEqual(<<"order_placed_v1">>, event_designed_v1:get_event_name(E)),
    ?assertEqual(<<"order_aggregate">>, event_designed_v1:get_aggregate_name(E)),
    ?assertEqual([#{<<"name">> => <<"order_id">>}], event_designed_v1:get_payload_fields(E)),
    ?assertEqual(<<"Order was placed">>, event_designed_v1:get_description(E)),
    ?assertEqual(<<"architect">>, event_designed_v1:get_designed_by(E)),
    ?assert(is_integer(event_designed_v1:get_designed_at(E))).

event_designed_v1_auto_id_test() ->
    E = event_designed_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>
    }),
    EvtId = event_designed_v1:get_event_id(E),
    ?assert(is_binary(EvtId)),
    ?assertMatch(<<"evt-", _/binary>>, EvtId).

event_designed_v1_to_map_includes_event_type_test() ->
    E = event_designed_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>
    }),
    Map = event_designed_v1:to_map(E),
    ?assertEqual(<<"event_designed_v1">>, maps:get(<<"event_type">>, Map)).

event_designed_v1_round_trip_test() ->
    E = event_designed_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        aggregate_name => <<"order_aggregate">>,
        payload_fields => [#{<<"name">> => <<"id">>}],
        description => <<"Placed">>,
        designed_by => <<"arch">>
    }),
    Map = event_designed_v1:to_map(E),
    {ok, E2} = event_designed_v1:from_map(Map),
    ?assertEqual(event_designed_v1:get_division_id(E),
                 event_designed_v1:get_division_id(E2)),
    ?assertEqual(event_designed_v1:get_event_id(E),
                 event_designed_v1:get_event_id(E2)),
    ?assertEqual(event_designed_v1:get_event_name(E),
                 event_designed_v1:get_event_name(E2)),
    ?assertEqual(event_designed_v1:get_aggregate_name(E),
                 event_designed_v1:get_aggregate_name(E2)),
    ?assertEqual(event_designed_v1:get_payload_fields(E),
                 event_designed_v1:get_payload_fields(E2)),
    ?assertEqual(event_designed_v1:get_description(E),
                 event_designed_v1:get_description(E2)),
    ?assertEqual(event_designed_v1:get_designed_by(E),
                 event_designed_v1:get_designed_by(E2)),
    ?assertEqual(event_designed_v1:get_designed_at(E),
                 event_designed_v1:get_designed_at(E2)).

event_designed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = event_designed_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"evt">>
    }),
    After = erlang:system_time(millisecond),
    T = event_designed_v1:get_designed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

event_designed_v1_to_map_all_fields_test() ->
    E = event_designed_v1:new(#{
        division_id => <<"div-1">>,
        event_id => <<"evt-explicit">>,
        event_name => <<"order_placed_v1">>,
        aggregate_name => <<"order_aggregate">>,
        payload_fields => [#{<<"name">> => <<"id">>}],
        description => <<"Desc">>,
        designed_by => <<"arch">>,
        designed_at => 7000
    }),
    Map = event_designed_v1:to_map(E),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"evt-explicit">>, maps:get(<<"event_id">>, Map)),
    ?assertEqual(<<"order_placed_v1">>, maps:get(<<"event_name">>, Map)),
    ?assertEqual(<<"order_aggregate">>, maps:get(<<"aggregate_name">>, Map)),
    ?assertEqual([#{<<"name">> => <<"id">>}], maps:get(<<"payload_fields">>, Map)),
    ?assertEqual(<<"Desc">>, maps:get(<<"description">>, Map)),
    ?assertEqual(<<"arch">>, maps:get(<<"designed_by">>, Map)),
    ?assertEqual(7000, maps:get(<<"designed_at">>, Map)).

%% ===================================================================
%% design_paused_v1 event tests
%% ===================================================================

design_paused_v1_new_test() ->
    E = design_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"waiting for review">>
    }),
    ?assertEqual(<<"div-1">>, design_paused_v1:get_division_id(E)),
    ?assertEqual(<<"waiting for review">>, design_paused_v1:get_reason(E)),
    ?assert(is_integer(design_paused_v1:get_paused_at(E))).

design_paused_v1_to_map_includes_event_type_test() ->
    E = design_paused_v1:new(#{division_id => <<"div-1">>}),
    Map = design_paused_v1:to_map(E),
    ?assertEqual(<<"design_paused_v1">>, maps:get(<<"event_type">>, Map)).

design_paused_v1_round_trip_test() ->
    E = design_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"review">>
    }),
    Map = design_paused_v1:to_map(E),
    {ok, E2} = design_paused_v1:from_map(Map),
    ?assertEqual(design_paused_v1:get_division_id(E),
                 design_paused_v1:get_division_id(E2)),
    ?assertEqual(design_paused_v1:get_paused_at(E),
                 design_paused_v1:get_paused_at(E2)),
    ?assertEqual(design_paused_v1:get_reason(E),
                 design_paused_v1:get_reason(E2)).

design_paused_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = design_paused_v1:new(#{division_id => <<"div-1">>}),
    After = erlang:system_time(millisecond),
    T = design_paused_v1:get_paused_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

design_paused_v1_optional_reason_test() ->
    E = design_paused_v1:new(#{division_id => <<"div-1">>}),
    ?assertEqual(undefined, design_paused_v1:get_reason(E)).

%% ===================================================================
%% design_resumed_v1 event tests
%% ===================================================================

design_resumed_v1_new_test() ->
    E = design_resumed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, design_resumed_v1:get_division_id(E)),
    ?assert(is_integer(design_resumed_v1:get_resumed_at(E))).

design_resumed_v1_to_map_includes_event_type_test() ->
    E = design_resumed_v1:new(#{division_id => <<"div-1">>}),
    Map = design_resumed_v1:to_map(E),
    ?assertEqual(<<"design_resumed_v1">>, maps:get(<<"event_type">>, Map)).

design_resumed_v1_round_trip_test() ->
    E = design_resumed_v1:new(#{
        division_id => <<"div-1">>
    }),
    Map = design_resumed_v1:to_map(E),
    {ok, E2} = design_resumed_v1:from_map(Map),
    ?assertEqual(design_resumed_v1:get_division_id(E),
                 design_resumed_v1:get_division_id(E2)),
    ?assertEqual(design_resumed_v1:get_resumed_at(E),
                 design_resumed_v1:get_resumed_at(E2)).

design_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = design_resumed_v1:new(#{division_id => <<"div-1">>}),
    After = erlang:system_time(millisecond),
    T = design_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

design_resumed_v1_to_map_all_fields_test() ->
    E = design_resumed_v1:new(#{
        division_id => <<"div-1">>,
        resumed_at => 5000
    }),
    Map = design_resumed_v1:to_map(E),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(5000, maps:get(<<"resumed_at">>, Map)).

%% ===================================================================
%% design_completed_v1 event tests
%% ===================================================================

design_completed_v1_new_test() ->
    E = design_completed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, design_completed_v1:get_division_id(E)),
    ?assert(is_integer(design_completed_v1:get_completed_at(E))).

design_completed_v1_to_map_includes_event_type_test() ->
    E = design_completed_v1:new(#{division_id => <<"div-1">>}),
    Map = design_completed_v1:to_map(E),
    ?assertEqual(<<"design_completed_v1">>, maps:get(<<"event_type">>, Map)).

design_completed_v1_round_trip_test() ->
    E = design_completed_v1:new(#{
        division_id => <<"div-1">>
    }),
    Map = design_completed_v1:to_map(E),
    {ok, E2} = design_completed_v1:from_map(Map),
    ?assertEqual(design_completed_v1:get_division_id(E),
                 design_completed_v1:get_division_id(E2)),
    ?assertEqual(design_completed_v1:get_completed_at(E),
                 design_completed_v1:get_completed_at(E2)).

design_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = design_completed_v1:new(#{division_id => <<"div-1">>}),
    After = erlang:system_time(millisecond),
    T = design_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

design_completed_v1_to_map_all_fields_test() ->
    E = design_completed_v1:new(#{
        division_id => <<"div-1">>,
        completed_at => 6000
    }),
    Map = design_completed_v1:to_map(E),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(6000, maps:get(<<"completed_at">>, Map)).

%% ===================================================================
%% design_archived_v1 event tests
%% ===================================================================

design_archived_v1_new_test() ->
    E = design_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"div-1">>, design_archived_v1:get_division_id(E)),
    ?assertEqual(<<"admin">>, design_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, design_archived_v1:get_reason(E)),
    ?assert(is_integer(design_archived_v1:get_archived_at(E))).

design_archived_v1_to_map_includes_event_type_test() ->
    E = design_archived_v1:new(#{division_id => <<"div-1">>}),
    Map = design_archived_v1:to_map(E),
    ?assertEqual(<<"design_archived_v1">>, maps:get(<<"event_type">>, Map)).

design_archived_v1_round_trip_test() ->
    E = design_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    Map = design_archived_v1:to_map(E),
    {ok, E2} = design_archived_v1:from_map(Map),
    ?assertEqual(design_archived_v1:get_division_id(E),
                 design_archived_v1:get_division_id(E2)),
    ?assertEqual(design_archived_v1:get_archived_at(E),
                 design_archived_v1:get_archived_at(E2)),
    ?assertEqual(design_archived_v1:get_archived_by(E),
                 design_archived_v1:get_archived_by(E2)),
    ?assertEqual(design_archived_v1:get_reason(E),
                 design_archived_v1:get_reason(E2)).

design_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = design_archived_v1:new(#{division_id => <<"div-1">>}),
    After = erlang:system_time(millisecond),
    T = design_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

design_archived_v1_optional_fields_test() ->
    E = design_archived_v1:new(#{division_id => <<"div-1">>}),
    ?assertEqual(undefined, design_archived_v1:get_archived_by(E)),
    ?assertEqual(undefined, design_archived_v1:get_reason(E)).

design_archived_v1_to_map_all_fields_test() ->
    E = design_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_at => 7000,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    Map = design_archived_v1:to_map(E),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(7000, maps:get(<<"archived_at">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).
