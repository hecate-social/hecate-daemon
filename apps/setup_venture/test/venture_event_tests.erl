%%% @doc Layer 2d: Event serialization tests.
%%% Tests new/1, to_map/1, from_map/1 round-trips, accessors,
%%% event_type inclusion, and timestamp auto-generation.
-module(venture_event_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% venture_setup_v1 event tests
%% ===================================================================

venture_setup_v1_new_test() ->
    E = venture_setup_v1:new(#{
        venture_id => <<"vent-1">>,
        name => <<"Test">>,
        brief => <<"brief">>,
        initiated_by => <<"user">>
    }),
    ?assertEqual(<<"vent-1">>, venture_setup_v1:get_venture_id(E)),
    ?assertEqual(<<"Test">>, venture_setup_v1:get_name(E)),
    ?assertEqual(<<"brief">>, venture_setup_v1:get_brief(E)),
    ?assertEqual(<<"user">>, venture_setup_v1:get_initiated_by(E)),
    ?assert(is_integer(venture_setup_v1:get_initiated_at(E))).

venture_setup_v1_to_map_includes_event_type_test() ->
    E = venture_setup_v1:new(#{venture_id => <<"v">>, name => <<"N">>}),
    Map = venture_setup_v1:to_map(E),
    ?assertEqual(<<"venture_setup_v1">>, maps:get(<<"event_type">>, Map)).

venture_setup_v1_round_trip_test() ->
    E = venture_setup_v1:new(#{
        venture_id => <<"vent-1">>,
        name => <<"Name">>,
        brief => <<"Brief">>,
        initiated_by => <<"user">>
    }),
    Map = venture_setup_v1:to_map(E),
    {ok, E2} = venture_setup_v1:from_map(Map),
    ?assertEqual(venture_setup_v1:get_venture_id(E), venture_setup_v1:get_venture_id(E2)),
    ?assertEqual(venture_setup_v1:get_name(E), venture_setup_v1:get_name(E2)),
    ?assertEqual(venture_setup_v1:get_brief(E), venture_setup_v1:get_brief(E2)),
    ?assertEqual(venture_setup_v1:get_initiated_at(E), venture_setup_v1:get_initiated_at(E2)).

venture_setup_v1_from_map_invalid_test() ->
    ?assertEqual({error, invalid_event}, venture_setup_v1:from_map(#{})),
    ?assertEqual({error, invalid_event}, venture_setup_v1:from_map(#{<<"name">> => <<"N">>})).

venture_setup_v1_timestamp_auto_test() ->
    Before = erlang:system_time(millisecond),
    E = venture_setup_v1:new(#{venture_id => <<"v">>, name => <<"N">>}),
    After = erlang:system_time(millisecond),
    T = venture_setup_v1:get_initiated_at(E),
    ?assert(T >= Before),
    ?assert(T =< After).

%% ===================================================================
%% venture_vision_refined_v1 event tests
%% ===================================================================

venture_vision_refined_v1_new_test() ->
    E = venture_vision_refined_v1:new(#{
        venture_id => <<"vent-1">>,
        brief => <<"new brief">>,
        repos => [<<"r1">>],
        skills => [<<"s1">>],
        context_map => #{<<"a">> => 1},
        refined_by => <<"user">>
    }),
    ?assertEqual(<<"vent-1">>, venture_vision_refined_v1:get_venture_id(E)),
    ?assertEqual(<<"new brief">>, venture_vision_refined_v1:get_brief(E)),
    ?assertEqual([<<"r1">>], venture_vision_refined_v1:get_repos(E)),
    ?assertEqual([<<"s1">>], venture_vision_refined_v1:get_skills(E)),
    ?assertEqual(#{<<"a">> => 1}, venture_vision_refined_v1:get_context_map(E)),
    ?assert(is_integer(venture_vision_refined_v1:get_refined_at(E))).

venture_vision_refined_v1_to_map_includes_event_type_test() ->
    E = venture_vision_refined_v1:new(#{venture_id => <<"v">>}),
    Map = venture_vision_refined_v1:to_map(E),
    ?assertEqual(<<"venture_vision_refined_v1">>, maps:get(<<"event_type">>, Map)).

venture_vision_refined_v1_round_trip_test() ->
    E = venture_vision_refined_v1:new(#{
        venture_id => <<"vent-1">>,
        brief => <<"b">>,
        repos => [<<"r">>]
    }),
    Map = venture_vision_refined_v1:to_map(E),
    {ok, E2} = venture_vision_refined_v1:from_map(Map),
    ?assertEqual(venture_vision_refined_v1:get_venture_id(E),
                 venture_vision_refined_v1:get_venture_id(E2)),
    ?assertEqual(venture_vision_refined_v1:get_brief(E),
                 venture_vision_refined_v1:get_brief(E2)).

venture_vision_refined_v1_from_map_invalid_test() ->
    ?assertEqual({error, invalid_event}, venture_vision_refined_v1:from_map(#{})).

%% ===================================================================
%% venture_vision_submitted_v1 event tests
%% ===================================================================

venture_vision_submitted_v1_new_test() ->
    E = venture_vision_submitted_v1:new(#{
        venture_id => <<"vent-1">>,
        submitted_by => <<"user">>
    }),
    ?assertEqual(<<"vent-1">>, venture_vision_submitted_v1:get_venture_id(E)),
    ?assertEqual(<<"user">>, venture_vision_submitted_v1:get_submitted_by(E)),
    ?assert(is_integer(venture_vision_submitted_v1:get_submitted_at(E))).

venture_vision_submitted_v1_to_map_includes_event_type_test() ->
    E = venture_vision_submitted_v1:new(#{venture_id => <<"v">>}),
    Map = venture_vision_submitted_v1:to_map(E),
    ?assertEqual(<<"venture_vision_submitted_v1">>, maps:get(<<"event_type">>, Map)).

venture_vision_submitted_v1_round_trip_test() ->
    E = venture_vision_submitted_v1:new(#{
        venture_id => <<"vent-1">>,
        submitted_by => <<"user">>
    }),
    Map = venture_vision_submitted_v1:to_map(E),
    {ok, E2} = venture_vision_submitted_v1:from_map(Map),
    ?assertEqual(venture_vision_submitted_v1:get_venture_id(E),
                 venture_vision_submitted_v1:get_venture_id(E2)),
    ?assertEqual(venture_vision_submitted_v1:get_submitted_by(E),
                 venture_vision_submitted_v1:get_submitted_by(E2)).

venture_vision_submitted_v1_from_map_invalid_test() ->
    ?assertEqual({error, invalid_event}, venture_vision_submitted_v1:from_map(#{})).

%% ===================================================================
%% venture_archived_v1 event tests
%% ===================================================================

venture_archived_v1_new_test() ->
    E = venture_archived_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    ?assertEqual(<<"vent-1">>, venture_archived_v1:get_venture_id(E)),
    ?assertEqual(<<"admin">>, venture_archived_v1:get_archived_by(E)),
    ?assertEqual(<<"done">>, venture_archived_v1:get_reason(E)),
    ?assert(is_integer(venture_archived_v1:get_archived_at(E))).

venture_archived_v1_to_map_includes_event_type_test() ->
    E = venture_archived_v1:new(#{venture_id => <<"v">>}),
    Map = venture_archived_v1:to_map(E),
    ?assertEqual(<<"venture_archived_v1">>, maps:get(<<"event_type">>, Map)).

venture_archived_v1_round_trip_test() ->
    E = venture_archived_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    Map = venture_archived_v1:to_map(E),
    {ok, E2} = venture_archived_v1:from_map(Map),
    ?assertEqual(venture_archived_v1:get_venture_id(E),
                 venture_archived_v1:get_venture_id(E2)),
    ?assertEqual(venture_archived_v1:get_reason(E),
                 venture_archived_v1:get_reason(E2)).

venture_archived_v1_from_map_invalid_test() ->
    ?assertEqual({error, invalid_event}, venture_archived_v1:from_map(#{})).
