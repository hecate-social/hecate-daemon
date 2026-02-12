%%% @doc Tests for maybe_record_test_result handler and record_test_result_v1 command.
%%% Covers valid recording with passed/failed counts and empty division_id rejection.
-module(record_test_result_tests).

-include_lib("eunit/include/eunit.hrl").

record_test_result_test_() ->
    [
        {"valid: handler returns event with passed and failed", fun valid_record_test_result/0},
        {"empty_division_id: command rejected",                 fun empty_division_id/0}
    ].

valid_record_test_result() ->
    {ok, Cmd} = record_test_result_v1:new(#{
        division_id => <<"div-1">>,
        result_id => <<"res-1">>,
        suite_id => <<"suite-1">>,
        passed => 10,
        failed => 2
    }),
    {ok, [Event]} = maybe_record_test_result:handle(Cmd),
    Map = test_result_recorded_v1:to_map(Event),
    ?assertEqual(10, maps:get(<<"passed">>, Map)),
    ?assertEqual(2, maps:get(<<"failed">>, Map)),
    ?assertEqual(<<"res-1">>, maps:get(<<"result_id">>, Map)),
    ?assertEqual(<<"test_result_recorded_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = record_test_result_v1:new(#{
        division_id => <<>>,
        result_id => <<"res-1">>,
        suite_id => <<"suite-1">>,
        passed => 10,
        failed => 2
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_record_test_result:handle(Cmd)).
