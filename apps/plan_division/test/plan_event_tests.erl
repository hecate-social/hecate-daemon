%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
-module(plan_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% plan_started_v1 event tests
%% ===================================================================

plan_started_v1_new_test() ->
    E = plan_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    ?assertEqual(<<"div-1">>, plan_started_v1:get_division_id(E)),
    ?assertEqual(<<"user@host">>, plan_started_v1:get_started_by(E)),
    ?assert(is_integer(plan_started_v1:get_started_at(E))).

plan_started_v1_to_map_includes_event_type_test() ->
    E = plan_started_v1:new(#{division_id => <<"d">>}),
    Map = plan_started_v1:to_map(E),
    ?assertEqual(<<"plan_started_v1">>, maps:get(<<"event_type">>, Map)).

plan_started_v1_round_trip_test() ->
    E = plan_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    Map = plan_started_v1:to_map(E),
    {ok, E2} = plan_started_v1:from_map(Map),
    ?assertEqual(plan_started_v1:get_division_id(E), plan_started_v1:get_division_id(E2)),
    ?assertEqual(plan_started_v1:get_started_by(E), plan_started_v1:get_started_by(E2)),
    ?assertEqual(plan_started_v1:get_started_at(E), plan_started_v1:get_started_at(E2)).

plan_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = plan_started_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = plan_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% desk_planned_v1 event tests
%% ===================================================================

desk_planned_v1_new_test() ->
    E = desk_planned_v1:new(#{
        division_id => <<"div-1">>,
        desk_name => <<"register_user">>,
        department => <<"CMD">>,
        aggregate_name => <<"user_aggregate">>,
        description => <<"Register user">>,
        priority => 1,
        planned_by => <<"user@host">>
    }),
    ?assertEqual(<<"div-1">>, desk_planned_v1:get_division_id(E)),
    ?assertEqual(<<"register_user">>, desk_planned_v1:get_desk_name(E)),
    ?assertEqual(<<"CMD">>, desk_planned_v1:get_department(E)),
    ?assertEqual(<<"user_aggregate">>, desk_planned_v1:get_aggregate_name(E)),
    ?assertEqual(<<"Register user">>, desk_planned_v1:get_description(E)),
    ?assertEqual(1, desk_planned_v1:get_priority(E)),
    ?assertEqual(<<"user@host">>, desk_planned_v1:get_planned_by(E)),
    ?assert(is_integer(desk_planned_v1:get_planned_at(E))).

desk_planned_v1_to_map_includes_event_type_test() ->
    E = desk_planned_v1:new(#{division_id => <<"d">>, desk_name => <<"n">>}),
    Map = desk_planned_v1:to_map(E),
    ?assertEqual(<<"desk_planned_v1">>, maps:get(<<"event_type">>, Map)).

desk_planned_v1_desk_id_auto_generated_test() ->
    E = desk_planned_v1:new(#{division_id => <<"d">>, desk_name => <<"n">>}),
    DeskId = desk_planned_v1:get_desk_id(E),
    ?assert(is_binary(DeskId)),
    ?assertMatch(<<"desk-", _/binary>>, DeskId).

desk_planned_v1_round_trip_test() ->
    E = desk_planned_v1:new(#{
        division_id => <<"div-1">>,
        desk_name => <<"register_user">>,
        department => <<"CMD">>,
        description => <<"Desc">>,
        priority => 2,
        planned_by => <<"user">>
    }),
    Map = desk_planned_v1:to_map(E),
    {ok, E2} = desk_planned_v1:from_map(Map),
    ?assertEqual(desk_planned_v1:get_division_id(E), desk_planned_v1:get_division_id(E2)),
    ?assertEqual(desk_planned_v1:get_desk_name(E), desk_planned_v1:get_desk_name(E2)),
    ?assertEqual(desk_planned_v1:get_department(E), desk_planned_v1:get_department(E2)),
    ?assertEqual(desk_planned_v1:get_priority(E), desk_planned_v1:get_priority(E2)),
    ?assertEqual(desk_planned_v1:get_planned_at(E), desk_planned_v1:get_planned_at(E2)).

desk_planned_v1_defaults_test() ->
    E = desk_planned_v1:new(#{division_id => <<"d">>, desk_name => <<"n">>}),
    ?assertEqual(<<"CMD">>, desk_planned_v1:get_department(E)),
    ?assertEqual(undefined, desk_planned_v1:get_aggregate_name(E)),
    ?assertEqual(undefined, desk_planned_v1:get_description(E)),
    ?assertEqual(0, desk_planned_v1:get_priority(E)),
    ?assertEqual(undefined, desk_planned_v1:get_planned_by(E)).

%% ===================================================================
%% dependency_planned_v1 event tests
%% ===================================================================

dependency_planned_v1_new_test() ->
    E = dependency_planned_v1:new(#{
        division_id => <<"div-1">>,
        from_desk => <<"register_user">>,
        to_desk => <<"send_welcome_email">>,
        dependency_type => <<"triggers">>,
        description => <<"Triggers welcome">>,
        planned_by => <<"user@host">>
    }),
    ?assertEqual(<<"div-1">>, dependency_planned_v1:get_division_id(E)),
    ?assertEqual(<<"register_user">>, dependency_planned_v1:get_from_desk(E)),
    ?assertEqual(<<"send_welcome_email">>, dependency_planned_v1:get_to_desk(E)),
    ?assertEqual(<<"triggers">>, dependency_planned_v1:get_dependency_type(E)),
    ?assertEqual(<<"Triggers welcome">>, dependency_planned_v1:get_description(E)),
    ?assertEqual(<<"user@host">>, dependency_planned_v1:get_planned_by(E)),
    ?assert(is_integer(dependency_planned_v1:get_planned_at(E))).

dependency_planned_v1_to_map_includes_event_type_test() ->
    E = dependency_planned_v1:new(#{
        division_id => <<"d">>,
        from_desk => <<"a">>,
        to_desk => <<"b">>,
        dependency_type => <<"triggers">>
    }),
    Map = dependency_planned_v1:to_map(E),
    ?assertEqual(<<"dependency_planned_v1">>, maps:get(<<"event_type">>, Map)).

dependency_planned_v1_dependency_id_auto_generated_test() ->
    E = dependency_planned_v1:new(#{
        division_id => <<"d">>,
        from_desk => <<"a">>,
        to_desk => <<"b">>,
        dependency_type => <<"triggers">>
    }),
    DepId = dependency_planned_v1:get_dependency_id(E),
    ?assert(is_binary(DepId)),
    ?assertMatch(<<"dep-", _/binary>>, DepId).

dependency_planned_v1_round_trip_test() ->
    E = dependency_planned_v1:new(#{
        division_id => <<"div-1">>,
        from_desk => <<"a">>,
        to_desk => <<"b">>,
        dependency_type => <<"triggers">>,
        description => <<"Desc">>
    }),
    Map = dependency_planned_v1:to_map(E),
    {ok, E2} = dependency_planned_v1:from_map(Map),
    ?assertEqual(dependency_planned_v1:get_division_id(E),
                 dependency_planned_v1:get_division_id(E2)),
    ?assertEqual(dependency_planned_v1:get_from_desk(E),
                 dependency_planned_v1:get_from_desk(E2)),
    ?assertEqual(dependency_planned_v1:get_to_desk(E),
                 dependency_planned_v1:get_to_desk(E2)),
    ?assertEqual(dependency_planned_v1:get_dependency_type(E),
                 dependency_planned_v1:get_dependency_type(E2)),
    ?assertEqual(dependency_planned_v1:get_planned_at(E),
                 dependency_planned_v1:get_planned_at(E2)).

dependency_planned_v1_defaults_test() ->
    E = dependency_planned_v1:new(#{
        division_id => <<"d">>,
        from_desk => <<"a">>,
        to_desk => <<"b">>,
        dependency_type => <<"triggers">>
    }),
    ?assertEqual(undefined, dependency_planned_v1:get_description(E)),
    ?assertEqual(undefined, dependency_planned_v1:get_planned_by(E)).

%% ===================================================================
%% plan_paused_v1 event tests
%% ===================================================================

plan_paused_v1_new_test() ->
    E = plan_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"needs review">>
    }),
    ?assertEqual(<<"div-1">>, plan_paused_v1:get_division_id(E)),
    ?assertEqual(<<"needs review">>, plan_paused_v1:get_reason(E)),
    ?assert(is_integer(plan_paused_v1:get_paused_at(E))).

plan_paused_v1_to_map_includes_event_type_test() ->
    E = plan_paused_v1:new(#{division_id => <<"d">>}),
    Map = plan_paused_v1:to_map(E),
    ?assertEqual(<<"plan_paused_v1">>, maps:get(<<"event_type">>, Map)).

plan_paused_v1_round_trip_test() ->
    E = plan_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"review">>
    }),
    Map = plan_paused_v1:to_map(E),
    {ok, E2} = plan_paused_v1:from_map(Map),
    ?assertEqual(plan_paused_v1:get_division_id(E), plan_paused_v1:get_division_id(E2)),
    ?assertEqual(plan_paused_v1:get_reason(E), plan_paused_v1:get_reason(E2)),
    ?assertEqual(plan_paused_v1:get_paused_at(E), plan_paused_v1:get_paused_at(E2)).

plan_paused_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = plan_paused_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = plan_paused_v1:get_paused_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

plan_paused_v1_reason_optional_test() ->
    E = plan_paused_v1:new(#{division_id => <<"d">>}),
    ?assertEqual(undefined, plan_paused_v1:get_reason(E)).

%% ===================================================================
%% plan_resumed_v1 event tests
%% ===================================================================

plan_resumed_v1_new_test() ->
    E = plan_resumed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, plan_resumed_v1:get_division_id(E)),
    ?assert(is_integer(plan_resumed_v1:get_resumed_at(E))).

plan_resumed_v1_to_map_includes_event_type_test() ->
    E = plan_resumed_v1:new(#{division_id => <<"d">>}),
    Map = plan_resumed_v1:to_map(E),
    ?assertEqual(<<"plan_resumed_v1">>, maps:get(<<"event_type">>, Map)).

plan_resumed_v1_round_trip_test() ->
    E = plan_resumed_v1:new(#{division_id => <<"div-1">>}),
    Map = plan_resumed_v1:to_map(E),
    {ok, E2} = plan_resumed_v1:from_map(Map),
    ?assertEqual(plan_resumed_v1:get_division_id(E), plan_resumed_v1:get_division_id(E2)),
    ?assertEqual(plan_resumed_v1:get_resumed_at(E), plan_resumed_v1:get_resumed_at(E2)).

plan_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = plan_resumed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = plan_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% plan_completed_v1 event tests
%% ===================================================================

plan_completed_v1_new_test() ->
    E = plan_completed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, plan_completed_v1:get_division_id(E)),
    ?assert(is_integer(plan_completed_v1:get_completed_at(E))).

plan_completed_v1_to_map_includes_event_type_test() ->
    E = plan_completed_v1:new(#{division_id => <<"d">>}),
    Map = plan_completed_v1:to_map(E),
    ?assertEqual(<<"plan_completed_v1">>, maps:get(<<"event_type">>, Map)).

plan_completed_v1_round_trip_test() ->
    E = plan_completed_v1:new(#{division_id => <<"div-1">>}),
    Map = plan_completed_v1:to_map(E),
    {ok, E2} = plan_completed_v1:from_map(Map),
    ?assertEqual(plan_completed_v1:get_division_id(E), plan_completed_v1:get_division_id(E2)),
    ?assertEqual(plan_completed_v1:get_completed_at(E), plan_completed_v1:get_completed_at(E2)).

plan_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = plan_completed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = plan_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% plan_archived_v1 event tests
%% ===================================================================

plan_archived_v1_new_test() ->
    E = plan_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"div-1">>, plan_archived_v1:get_division_id(E)),
    ?assertEqual(<<"admin">>, plan_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, plan_archived_v1:get_reason(E)),
    ?assert(is_integer(plan_archived_v1:get_archived_at(E))).

plan_archived_v1_to_map_includes_event_type_test() ->
    E = plan_archived_v1:new(#{division_id => <<"d">>}),
    Map = plan_archived_v1:to_map(E),
    ?assertEqual(<<"plan_archived_v1">>, maps:get(<<"event_type">>, Map)).

plan_archived_v1_round_trip_test() ->
    E = plan_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    Map = plan_archived_v1:to_map(E),
    {ok, E2} = plan_archived_v1:from_map(Map),
    ?assertEqual(plan_archived_v1:get_division_id(E), plan_archived_v1:get_division_id(E2)),
    ?assertEqual(plan_archived_v1:get_archived_by(E), plan_archived_v1:get_archived_by(E2)),
    ?assertEqual(plan_archived_v1:get_reason(E), plan_archived_v1:get_reason(E2)),
    ?assertEqual(plan_archived_v1:get_archived_at(E), plan_archived_v1:get_archived_at(E2)).

plan_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = plan_archived_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = plan_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

plan_archived_v1_optional_fields_test() ->
    E = plan_archived_v1:new(#{division_id => <<"d">>}),
    ?assertEqual(undefined, plan_archived_v1:get_archived_by(E)),
    ?assertEqual(undefined, plan_archived_v1:get_reason(E)).
