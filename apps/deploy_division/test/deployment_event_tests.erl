%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
-module(deployment_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% deployment_started_v1 event tests
%% ===================================================================

deployment_started_v1_new_test() ->
    E = deployment_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user">>
    }),
    ?assertEqual(<<"div-1">>, deployment_started_v1:get_division_id(E)),
    ?assertEqual(<<"user">>, deployment_started_v1:get_started_by(E)),
    ?assert(is_integer(deployment_started_v1:get_started_at(E))).

deployment_started_v1_to_map_includes_event_type_test() ->
    E = deployment_started_v1:new(#{division_id => <<"d">>}),
    Map = deployment_started_v1:to_map(E),
    ?assertEqual(<<"deployment_started_v1">>, maps:get(<<"event_type">>, Map)).

deployment_started_v1_round_trip_test() ->
    E = deployment_started_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user">>,
        started_at => 1234
    }),
    Map = deployment_started_v1:to_map(E),
    {ok, E2} = deployment_started_v1:from_map(Map),
    ?assertEqual(deployment_started_v1:get_division_id(E),
                 deployment_started_v1:get_division_id(E2)),
    ?assertEqual(deployment_started_v1:get_started_at(E),
                 deployment_started_v1:get_started_at(E2)),
    ?assertEqual(deployment_started_v1:get_started_by(E),
                 deployment_started_v1:get_started_by(E2)).

deployment_started_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = deployment_started_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = deployment_started_v1:get_started_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% release_deployed_v1 event tests
%% ===================================================================

release_deployed_v1_new_test() ->
    E = release_deployed_v1:new(#{
        division_id => <<"div-1">>,
        release_name => <<"myapp">>,
        release_version => <<"1.0.0">>,
        target_env => <<"production">>,
        deployed_by => <<"deployer">>
    }),
    ?assertEqual(<<"div-1">>, release_deployed_v1:get_division_id(E)),
    ?assertEqual(<<"myapp">>, release_deployed_v1:get_release_name(E)),
    ?assertEqual(<<"1.0.0">>, release_deployed_v1:get_release_version(E)),
    ?assertEqual(<<"production">>, release_deployed_v1:get_target_env(E)),
    ?assertEqual(<<"deployer">>, release_deployed_v1:get_deployed_by(E)),
    ?assert(is_integer(release_deployed_v1:get_deployed_at(E))),
    ?assert(is_binary(release_deployed_v1:get_release_id(E))).

release_deployed_v1_to_map_includes_event_type_test() ->
    E = release_deployed_v1:new(#{division_id => <<"d">>, release_name => <<"n">>}),
    Map = release_deployed_v1:to_map(E),
    ?assertEqual(<<"release_deployed_v1">>, maps:get(<<"event_type">>, Map)).

release_deployed_v1_round_trip_test() ->
    E = release_deployed_v1:new(#{
        division_id => <<"div-1">>,
        release_name => <<"myapp">>,
        release_version => <<"2.0.0">>,
        target_env => <<"staging">>,
        deployed_by => <<"user">>,
        deployed_at => 5000
    }),
    Map = release_deployed_v1:to_map(E),
    {ok, E2} = release_deployed_v1:from_map(Map),
    ?assertEqual(release_deployed_v1:get_division_id(E),
                 release_deployed_v1:get_division_id(E2)),
    ?assertEqual(release_deployed_v1:get_release_id(E),
                 release_deployed_v1:get_release_id(E2)),
    ?assertEqual(release_deployed_v1:get_release_name(E),
                 release_deployed_v1:get_release_name(E2)),
    ?assertEqual(release_deployed_v1:get_release_version(E),
                 release_deployed_v1:get_release_version(E2)),
    ?assertEqual(release_deployed_v1:get_target_env(E),
                 release_deployed_v1:get_target_env(E2)),
    ?assertEqual(release_deployed_v1:get_deployed_by(E),
                 release_deployed_v1:get_deployed_by(E2)),
    ?assertEqual(release_deployed_v1:get_deployed_at(E),
                 release_deployed_v1:get_deployed_at(E2)).

release_deployed_v1_auto_generates_release_id_test() ->
    E = release_deployed_v1:new(#{
        division_id => <<"div-1">>,
        release_name => <<"myapp">>
    }),
    ?assertEqual(<<"rel-div-1-myapp">>, release_deployed_v1:get_release_id(E)).

release_deployed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = release_deployed_v1:new(#{division_id => <<"d">>, release_name => <<"n">>}),
    After = erlang:system_time(millisecond),
    T = release_deployed_v1:get_deployed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% rollout_staged_v1 event tests
%% ===================================================================

rollout_staged_v1_new_test() ->
    E = rollout_staged_v1:new(#{
        division_id => <<"div-1">>,
        release_id => <<"rel-div-1-myapp">>,
        stage_name => <<"canary">>,
        stage_percentage => 10,
        description => <<"Canary rollout">>
    }),
    ?assertEqual(<<"div-1">>, rollout_staged_v1:get_division_id(E)),
    ?assertEqual(<<"rel-div-1-myapp">>, rollout_staged_v1:get_release_id(E)),
    ?assertEqual(<<"canary">>, rollout_staged_v1:get_stage_name(E)),
    ?assertEqual(10, rollout_staged_v1:get_stage_percentage(E)),
    ?assertEqual(<<"Canary rollout">>, rollout_staged_v1:get_description(E)),
    ?assert(is_integer(rollout_staged_v1:get_staged_at(E))),
    ?assert(is_binary(rollout_staged_v1:get_stage_id(E))).

rollout_staged_v1_to_map_includes_event_type_test() ->
    E = rollout_staged_v1:new(#{division_id => <<"d">>,
                                release_id => <<"r">>,
                                stage_name => <<"s">>}),
    Map = rollout_staged_v1:to_map(E),
    ?assertEqual(<<"rollout_staged_v1">>, maps:get(<<"event_type">>, Map)).

rollout_staged_v1_round_trip_test() ->
    E = rollout_staged_v1:new(#{
        division_id => <<"div-1">>,
        release_id => <<"rel-div-1-myapp">>,
        stage_name => <<"canary">>,
        stage_percentage => 25,
        description => <<"Quarter rollout">>,
        staged_at => 9000
    }),
    Map = rollout_staged_v1:to_map(E),
    {ok, E2} = rollout_staged_v1:from_map(Map),
    ?assertEqual(rollout_staged_v1:get_division_id(E),
                 rollout_staged_v1:get_division_id(E2)),
    ?assertEqual(rollout_staged_v1:get_stage_id(E),
                 rollout_staged_v1:get_stage_id(E2)),
    ?assertEqual(rollout_staged_v1:get_release_id(E),
                 rollout_staged_v1:get_release_id(E2)),
    ?assertEqual(rollout_staged_v1:get_stage_name(E),
                 rollout_staged_v1:get_stage_name(E2)),
    ?assertEqual(rollout_staged_v1:get_stage_percentage(E),
                 rollout_staged_v1:get_stage_percentage(E2)),
    ?assertEqual(rollout_staged_v1:get_description(E),
                 rollout_staged_v1:get_description(E2)),
    ?assertEqual(rollout_staged_v1:get_staged_at(E),
                 rollout_staged_v1:get_staged_at(E2)).

rollout_staged_v1_auto_generates_stage_id_test() ->
    E = rollout_staged_v1:new(#{
        division_id => <<"div-1">>,
        release_id => <<"rel-div-1-myapp">>,
        stage_name => <<"canary">>
    }),
    ?assertEqual(<<"stage-rel-div-1-myapp-canary">>,
                 rollout_staged_v1:get_stage_id(E)).

rollout_staged_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = rollout_staged_v1:new(#{division_id => <<"d">>,
                                release_id => <<"r">>,
                                stage_name => <<"s">>}),
    After = erlang:system_time(millisecond),
    T = rollout_staged_v1:get_staged_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% deployment_paused_v1 event tests
%% ===================================================================

deployment_paused_v1_new_test() ->
    E = deployment_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"incident">>
    }),
    ?assertEqual(<<"div-1">>, deployment_paused_v1:get_division_id(E)),
    ?assertEqual(<<"incident">>, deployment_paused_v1:get_reason(E)),
    ?assert(is_integer(deployment_paused_v1:get_paused_at(E))).

deployment_paused_v1_to_map_includes_event_type_test() ->
    E = deployment_paused_v1:new(#{division_id => <<"d">>}),
    Map = deployment_paused_v1:to_map(E),
    ?assertEqual(<<"deployment_paused_v1">>, maps:get(<<"event_type">>, Map)).

deployment_paused_v1_round_trip_test() ->
    E = deployment_paused_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"incident">>,
        paused_at => 4000
    }),
    Map = deployment_paused_v1:to_map(E),
    {ok, E2} = deployment_paused_v1:from_map(Map),
    ?assertEqual(deployment_paused_v1:get_division_id(E),
                 deployment_paused_v1:get_division_id(E2)),
    ?assertEqual(deployment_paused_v1:get_paused_at(E),
                 deployment_paused_v1:get_paused_at(E2)),
    ?assertEqual(deployment_paused_v1:get_reason(E),
                 deployment_paused_v1:get_reason(E2)).

deployment_paused_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = deployment_paused_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = deployment_paused_v1:get_paused_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% deployment_resumed_v1 event tests
%% ===================================================================

deployment_resumed_v1_new_test() ->
    E = deployment_resumed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, deployment_resumed_v1:get_division_id(E)),
    ?assert(is_integer(deployment_resumed_v1:get_resumed_at(E))).

deployment_resumed_v1_to_map_includes_event_type_test() ->
    E = deployment_resumed_v1:new(#{division_id => <<"d">>}),
    Map = deployment_resumed_v1:to_map(E),
    ?assertEqual(<<"deployment_resumed_v1">>, maps:get(<<"event_type">>, Map)).

deployment_resumed_v1_round_trip_test() ->
    E = deployment_resumed_v1:new(#{
        division_id => <<"div-1">>,
        resumed_at => 5000
    }),
    Map = deployment_resumed_v1:to_map(E),
    {ok, E2} = deployment_resumed_v1:from_map(Map),
    ?assertEqual(deployment_resumed_v1:get_division_id(E),
                 deployment_resumed_v1:get_division_id(E2)),
    ?assertEqual(deployment_resumed_v1:get_resumed_at(E),
                 deployment_resumed_v1:get_resumed_at(E2)).

deployment_resumed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = deployment_resumed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = deployment_resumed_v1:get_resumed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% deployment_completed_v1 event tests
%% ===================================================================

deployment_completed_v1_new_test() ->
    E = deployment_completed_v1:new(#{
        division_id => <<"div-1">>
    }),
    ?assertEqual(<<"div-1">>, deployment_completed_v1:get_division_id(E)),
    ?assert(is_integer(deployment_completed_v1:get_completed_at(E))).

deployment_completed_v1_to_map_includes_event_type_test() ->
    E = deployment_completed_v1:new(#{division_id => <<"d">>}),
    Map = deployment_completed_v1:to_map(E),
    ?assertEqual(<<"deployment_completed_v1">>, maps:get(<<"event_type">>, Map)).

deployment_completed_v1_round_trip_test() ->
    E = deployment_completed_v1:new(#{
        division_id => <<"div-1">>,
        completed_at => 6000
    }),
    Map = deployment_completed_v1:to_map(E),
    {ok, E2} = deployment_completed_v1:from_map(Map),
    ?assertEqual(deployment_completed_v1:get_division_id(E),
                 deployment_completed_v1:get_division_id(E2)),
    ?assertEqual(deployment_completed_v1:get_completed_at(E),
                 deployment_completed_v1:get_completed_at(E2)).

deployment_completed_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = deployment_completed_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = deployment_completed_v1:get_completed_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% deployment_archived_v1 event tests
%% ===================================================================

deployment_archived_v1_new_test() ->
    E = deployment_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"div-1">>, deployment_archived_v1:get_division_id(E)),
    ?assertEqual(<<"admin">>, deployment_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, deployment_archived_v1:get_reason(E)),
    ?assert(is_integer(deployment_archived_v1:get_archived_at(E))).

deployment_archived_v1_to_map_includes_event_type_test() ->
    E = deployment_archived_v1:new(#{division_id => <<"d">>}),
    Map = deployment_archived_v1:to_map(E),
    ?assertEqual(<<"deployment_archived_v1">>, maps:get(<<"event_type">>, Map)).

deployment_archived_v1_round_trip_test() ->
    E = deployment_archived_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>,
        archived_at => 7000
    }),
    Map = deployment_archived_v1:to_map(E),
    {ok, E2} = deployment_archived_v1:from_map(Map),
    ?assertEqual(deployment_archived_v1:get_division_id(E),
                 deployment_archived_v1:get_division_id(E2)),
    ?assertEqual(deployment_archived_v1:get_archived_at(E),
                 deployment_archived_v1:get_archived_at(E2)),
    ?assertEqual(deployment_archived_v1:get_archived_by(E),
                 deployment_archived_v1:get_archived_by(E2)),
    ?assertEqual(deployment_archived_v1:get_reason(E),
                 deployment_archived_v1:get_reason(E2)).

deployment_archived_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = deployment_archived_v1:new(#{division_id => <<"d">>}),
    After = erlang:system_time(millisecond),
    T = deployment_archived_v1:get_archived_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).
