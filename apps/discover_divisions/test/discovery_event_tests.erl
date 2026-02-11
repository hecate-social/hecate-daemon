%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation for all
%%% 6 event modules in the discover_divisions app.
-module(discovery_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% discovery_started_v1 event tests
%% ===================================================================

discovery_started_v1_new_test() ->
    E = discovery_started_v1:new(#{
        venture_id => <<"vent-1">>,
        started_by => <<"user@host">>
    }),
    ?assertEqual(<<"vent-1">>, discovery_started_v1:get_venture_id(E)),
    ?assertEqual(<<"user@host">>, discovery_started_v1:get_started_by(E)),
    ?assert(is_integer(discovery_started_v1:get_started_at(E))).

discovery_started_v1_to_map_includes_event_type_test() ->
    E = discovery_started_v1:new(#{venture_id => <<"v">>}),
    Map = discovery_started_v1:to_map(E),
    ?assertEqual(<<"discovery_started_v1">>, maps:get(<<"event_type">>, Map)).

discovery_started_v1_round_trip_test() ->
    E = discovery_started_v1:new(#{
        venture_id => <<"vent-1">>,
        started_by => <<"user@host">>
    }),
    Map = discovery_started_v1:to_map(E),
    {ok, E2} = discovery_started_v1:from_map(Map),
    ?assertEqual(discovery_started_v1:get_venture_id(E),
                 discovery_started_v1:get_venture_id(E2)),
    ?assertEqual(discovery_started_v1:get_started_at(E),
                 discovery_started_v1:get_started_at(E2)),
    ?assertEqual(discovery_started_v1:get_started_by(E),
                 discovery_started_v1:get_started_by(E2)).

discovery_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = discovery_started_v1:new(#{venture_id => <<"v">>}),
    After = erlang:system_time(millisecond),
    T = discovery_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

discovery_started_v1_from_map_with_binary_keys_test() ->
    Map = #{<<"venture_id">> => <<"vent-1">>,
            <<"started_at">> => 1000,
            <<"started_by">> => <<"test">>},
    {ok, E} = discovery_started_v1:from_map(Map),
    ?assertEqual(<<"vent-1">>, discovery_started_v1:get_venture_id(E)),
    ?assertEqual(1000, discovery_started_v1:get_started_at(E)).

%% ===================================================================
%% division_discovered_v1 event tests
%% ===================================================================

division_discovered_v1_new_test() ->
    E = division_discovered_v1:new(#{
        venture_id => <<"vent-1">>,
        context_name => <<"auth">>,
        description => <<"Auth context">>,
        identified_by => <<"user@host">>
    }),
    ?assertEqual(<<"vent-1">>, division_discovered_v1:get_venture_id(E)),
    ?assertEqual(<<"auth">>, division_discovered_v1:get_context_name(E)),
    ?assertEqual(<<"Auth context">>, division_discovered_v1:get_description(E)),
    ?assertEqual(<<"user@host">>, division_discovered_v1:get_identified_by(E)),
    ?assert(is_binary(division_discovered_v1:get_division_id(E))),
    ?assert(is_integer(division_discovered_v1:get_discovered_at(E))).

division_discovered_v1_to_map_includes_event_type_test() ->
    E = division_discovered_v1:new(#{
        venture_id => <<"v">>,
        context_name => <<"c">>
    }),
    Map = division_discovered_v1:to_map(E),
    ?assertEqual(<<"division_discovered_v1">>, maps:get(<<"event_type">>, Map)).

division_discovered_v1_round_trip_test() ->
    E = division_discovered_v1:new(#{
        venture_id => <<"vent-1">>,
        context_name => <<"auth">>,
        description => <<"Auth ctx">>,
        identified_by => <<"user">>
    }),
    Map = division_discovered_v1:to_map(E),
    {ok, E2} = division_discovered_v1:from_map(Map),
    ?assertEqual(division_discovered_v1:get_venture_id(E),
                 division_discovered_v1:get_venture_id(E2)),
    ?assertEqual(division_discovered_v1:get_division_id(E),
                 division_discovered_v1:get_division_id(E2)),
    ?assertEqual(division_discovered_v1:get_context_name(E),
                 division_discovered_v1:get_context_name(E2)),
    ?assertEqual(division_discovered_v1:get_description(E),
                 division_discovered_v1:get_description(E2)),
    ?assertEqual(division_discovered_v1:get_identified_by(E),
                 division_discovered_v1:get_identified_by(E2)),
    ?assertEqual(division_discovered_v1:get_discovered_at(E),
                 division_discovered_v1:get_discovered_at(E2)).

division_discovered_v1_auto_generates_division_id_test() ->
    E = division_discovered_v1:new(#{
        venture_id => <<"vent-1">>,
        context_name => <<"auth">>
    }),
    DivId = division_discovered_v1:get_division_id(E),
    ?assert(is_binary(DivId)),
    %% Division IDs start with "div-"
    ?assertMatch(<<"div-", _/binary>>, DivId).

division_discovered_v1_explicit_division_id_test() ->
    E = division_discovered_v1:new(#{
        venture_id => <<"vent-1">>,
        context_name => <<"auth">>,
        division_id => <<"my-div-id">>
    }),
    ?assertEqual(<<"my-div-id">>, division_discovered_v1:get_division_id(E)).

%% ===================================================================
%% discovery_paused_v1 event tests
%% ===================================================================

discovery_paused_v1_new_test() ->
    E = discovery_paused_v1:new(#{
        venture_id => <<"vent-1">>,
        reason => <<"needs review">>
    }),
    ?assertEqual(<<"vent-1">>, discovery_paused_v1:get_venture_id(E)),
    ?assertEqual(<<"needs review">>, discovery_paused_v1:get_reason(E)),
    ?assert(is_integer(discovery_paused_v1:get_paused_at(E))).

discovery_paused_v1_to_map_includes_event_type_test() ->
    E = discovery_paused_v1:new(#{venture_id => <<"v">>}),
    Map = discovery_paused_v1:to_map(E),
    ?assertEqual(<<"discovery_paused_v1">>, maps:get(<<"event_type">>, Map)).

discovery_paused_v1_round_trip_test() ->
    E = discovery_paused_v1:new(#{
        venture_id => <<"vent-1">>,
        reason => <<"review">>
    }),
    Map = discovery_paused_v1:to_map(E),
    {ok, E2} = discovery_paused_v1:from_map(Map),
    ?assertEqual(discovery_paused_v1:get_venture_id(E),
                 discovery_paused_v1:get_venture_id(E2)),
    ?assertEqual(discovery_paused_v1:get_paused_at(E),
                 discovery_paused_v1:get_paused_at(E2)),
    ?assertEqual(discovery_paused_v1:get_reason(E),
                 discovery_paused_v1:get_reason(E2)).

discovery_paused_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = discovery_paused_v1:new(#{venture_id => <<"v">>}),
    After = erlang:system_time(millisecond),
    T = discovery_paused_v1:get_paused_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% discovery_resumed_v1 event tests
%% ===================================================================

discovery_resumed_v1_new_test() ->
    E = discovery_resumed_v1:new(#{venture_id => <<"vent-1">>}),
    ?assertEqual(<<"vent-1">>, discovery_resumed_v1:get_venture_id(E)),
    ?assert(is_integer(discovery_resumed_v1:get_resumed_at(E))).

discovery_resumed_v1_to_map_includes_event_type_test() ->
    E = discovery_resumed_v1:new(#{venture_id => <<"v">>}),
    Map = discovery_resumed_v1:to_map(E),
    ?assertEqual(<<"discovery_resumed_v1">>, maps:get(<<"event_type">>, Map)).

discovery_resumed_v1_round_trip_test() ->
    E = discovery_resumed_v1:new(#{venture_id => <<"vent-1">>}),
    Map = discovery_resumed_v1:to_map(E),
    {ok, E2} = discovery_resumed_v1:from_map(Map),
    ?assertEqual(discovery_resumed_v1:get_venture_id(E),
                 discovery_resumed_v1:get_venture_id(E2)),
    ?assertEqual(discovery_resumed_v1:get_resumed_at(E),
                 discovery_resumed_v1:get_resumed_at(E2)).

discovery_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = discovery_resumed_v1:new(#{venture_id => <<"v">>}),
    After = erlang:system_time(millisecond),
    T = discovery_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% discovery_completed_v1 event tests
%% ===================================================================

discovery_completed_v1_new_test() ->
    E = discovery_completed_v1:new(#{venture_id => <<"vent-1">>}),
    ?assertEqual(<<"vent-1">>, discovery_completed_v1:get_venture_id(E)),
    ?assert(is_integer(discovery_completed_v1:get_completed_at(E))).

discovery_completed_v1_to_map_includes_event_type_test() ->
    E = discovery_completed_v1:new(#{venture_id => <<"v">>}),
    Map = discovery_completed_v1:to_map(E),
    ?assertEqual(<<"discovery_completed_v1">>, maps:get(<<"event_type">>, Map)).

discovery_completed_v1_round_trip_test() ->
    E = discovery_completed_v1:new(#{venture_id => <<"vent-1">>}),
    Map = discovery_completed_v1:to_map(E),
    {ok, E2} = discovery_completed_v1:from_map(Map),
    ?assertEqual(discovery_completed_v1:get_venture_id(E),
                 discovery_completed_v1:get_venture_id(E2)),
    ?assertEqual(discovery_completed_v1:get_completed_at(E),
                 discovery_completed_v1:get_completed_at(E2)).

discovery_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = discovery_completed_v1:new(#{venture_id => <<"v">>}),
    After = erlang:system_time(millisecond),
    T = discovery_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% discovery_archived_v1 event tests
%% ===================================================================

discovery_archived_v1_new_test() ->
    E = discovery_archived_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"vent-1">>, discovery_archived_v1:get_venture_id(E)),
    ?assertEqual(<<"admin">>, discovery_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, discovery_archived_v1:get_reason(E)),
    ?assert(is_integer(discovery_archived_v1:get_archived_at(E))).

discovery_archived_v1_to_map_includes_event_type_test() ->
    E = discovery_archived_v1:new(#{venture_id => <<"v">>}),
    Map = discovery_archived_v1:to_map(E),
    ?assertEqual(<<"discovery_archived_v1">>, maps:get(<<"event_type">>, Map)).

discovery_archived_v1_round_trip_test() ->
    E = discovery_archived_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    Map = discovery_archived_v1:to_map(E),
    {ok, E2} = discovery_archived_v1:from_map(Map),
    ?assertEqual(discovery_archived_v1:get_venture_id(E),
                 discovery_archived_v1:get_venture_id(E2)),
    ?assertEqual(discovery_archived_v1:get_archived_at(E),
                 discovery_archived_v1:get_archived_at(E2)),
    ?assertEqual(discovery_archived_v1:get_archived_by(E),
                 discovery_archived_v1:get_archived_by(E2)),
    ?assertEqual(discovery_archived_v1:get_reason(E),
                 discovery_archived_v1:get_reason(E2)).

discovery_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = discovery_archived_v1:new(#{venture_id => <<"v">>}),
    After = erlang:system_time(millisecond),
    T = discovery_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

discovery_archived_v1_optional_fields_test() ->
    E = discovery_archived_v1:new(#{venture_id => <<"vent-1">>}),
    ?assertEqual(undefined, discovery_archived_v1:get_archived_by(E)),
    ?assertEqual(undefined, discovery_archived_v1:get_reason(E)).
