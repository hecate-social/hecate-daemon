%%% @doc Tests for projection_event:to_map/1.
%%%
%%% Proves that ReckonDB #event{} records are correctly flattened
%%% to maps that projections can consume. This test exists because
%%% ReckonDB emitters send {events, [#event{}]} records, but all
%%% projection modules expect flat maps. Passing raw #event{} records
%%% to maps:find/2 causes a badarg crash.
-module(projection_event_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/esdb_gater_types.hrl").

%% ===================================================================
%% Helpers
%% ===================================================================

sample_event_record() ->
    #event{
        event_id = <<"evt-test-123">>,
        event_type = <<"venture_initiated_v1">>,
        stream_id = <<"venture_aggregate-v-test-1">>,
        version = 0,
        data = #{
            venture_id => <<"v-test-1">>,
            name => <<"Test Venture">>,
            brief => <<"A test venture">>,
            initiated_by => <<"user@test">>,
            initiated_at => 1000
        },
        metadata = #{correlation_id => <<"req-abc">>},
        timestamp = 1000,
        epoch_us = 1000000
    }.

sample_event_record_no_data() ->
    #event{
        event_id = <<"evt-test-456">>,
        event_type = <<"some_event_v1">>,
        stream_id = <<"some_stream">>,
        version = 1,
        data = undefined,
        metadata = #{},
        timestamp = 2000,
        epoch_us = 2000000
    }.

%% ===================================================================
%% Tests
%% ===================================================================

to_map_test_() ->
    [
        {"raw #event{} record crashes maps:find (proving the bug)",
         fun record_crashes_maps_find/0},
        {"to_map flattens #event{} with data map",
         fun to_map_flattens_event_with_data/0},
        {"to_map handles #event{} with no data",
         fun to_map_handles_event_without_data/0},
        {"to_map passes through existing maps",
         fun to_map_passes_through_maps/0},
        {"envelope fields win on collision with data fields",
         fun envelope_wins_on_collision/0}
    ].

record_crashes_maps_find() ->
    E = sample_event_record(),
    %% This is the exact bug: passing #event{} record to maps:find
    %% OTP 28+ raises {badmap, Value} instead of badarg
    ?assertError({badmap, _}, maps:find(venture_id, E)).

to_map_flattens_event_with_data() ->
    E = sample_event_record(),
    Map = projection_event:to_map(E),
    ?assert(is_map(Map)),
    %% Business data fields are at top level
    ?assertEqual(<<"v-test-1">>, maps:get(venture_id, Map)),
    ?assertEqual(<<"Test Venture">>, maps:get(name, Map)),
    ?assertEqual(<<"A test venture">>, maps:get(brief, Map)),
    ?assertEqual(<<"user@test">>, maps:get(initiated_by, Map)),
    ?assertEqual(1000, maps:get(initiated_at, Map)),
    %% Envelope fields are also at top level
    ?assertEqual(<<"evt-test-123">>, maps:get(event_id, Map)),
    ?assertEqual(<<"venture_initiated_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"venture_aggregate-v-test-1">>, maps:get(stream_id, Map)),
    ?assertEqual(0, maps:get(version, Map)),
    ?assertEqual(#{correlation_id => <<"req-abc">>}, maps:get(metadata, Map)),
    ?assertEqual(1000, maps:get(timestamp, Map)),
    ?assertEqual(1000000, maps:get(epoch_us, Map)).

to_map_handles_event_without_data() ->
    E = sample_event_record_no_data(),
    Map = projection_event:to_map(E),
    ?assert(is_map(Map)),
    %% Only envelope fields present
    ?assertEqual(<<"evt-test-456">>, maps:get(event_id, Map)),
    ?assertEqual(<<"some_event_v1">>, maps:get(event_type, Map)),
    ?assertEqual(1, maps:get(version, Map)),
    %% No data fields
    ?assertEqual(error, maps:find(venture_id, Map)).

to_map_passes_through_maps() ->
    FlatMap = #{venture_id => <<"v-1">>, name => <<"Test">>},
    ?assertEqual(FlatMap, projection_event:to_map(FlatMap)).

envelope_wins_on_collision() ->
    %% If data map has a field with the same name as an envelope field,
    %% the envelope value wins (maps:merge(Data, Envelope) — Envelope second)
    E = #event{
        event_id = <<"evt-collision">>,
        event_type = <<"test_v1">>,
        stream_id = <<"test-stream">>,
        version = 5,
        data = #{version => 999, event_type => <<"wrong">>},
        metadata = #{},
        timestamp = 3000,
        epoch_us = 3000000
    },
    Map = projection_event:to_map(E),
    %% Envelope values win
    ?assertEqual(5, maps:get(version, Map)),
    ?assertEqual(<<"test_v1">>, maps:get(event_type, Map)).
