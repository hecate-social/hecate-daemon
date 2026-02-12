%%% @doc Tests for maybe_run_test_suite handler and run_test_suite_v1 command.
%%% Covers valid suite run, duplicate detection, and empty division_id rejection.
-module(run_test_suite_tests).

-include_lib("eunit/include/eunit.hrl").

run_test_suite_test_() ->
    [
        {"valid: handler returns event with suite_id", fun valid_run_test_suite/0},
        {"duplicate: rejects already run suite",       fun duplicate_suite/0},
        {"empty_division_id: command rejected",        fun empty_division_id/0}
    ].

valid_run_test_suite() ->
    {ok, Cmd} = run_test_suite_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"suite-1">>,
        suite_name => <<"unit_tests">>
    }),
    Context = #{test_suites => #{}},
    {ok, [Event]} = maybe_run_test_suite:handle(Cmd, Context),
    Map = test_suite_run_v1:to_map(Event),
    ?assertEqual(<<"suite-1">>, maps:get(<<"suite_id">>, Map)),
    ?assertEqual(<<"unit_tests">>, maps:get(<<"suite_name">>, Map)),
    ?assertEqual(<<"test_suite_run_v1">>, maps:get(<<"event_type">>, Map)).

duplicate_suite() ->
    {ok, Cmd} = run_test_suite_v1:new(#{
        division_id => <<"div-1">>,
        suite_id => <<"suite-1">>,
        suite_name => <<"unit_tests">>
    }),
    Context = #{test_suites => #{<<"suite-1">> => #{}}},
    ?assertEqual({error, suite_already_run},
                 maybe_run_test_suite:handle(Cmd, Context)).

empty_division_id() ->
    {ok, Cmd} = run_test_suite_v1:new(#{
        division_id => <<>>,
        suite_id => <<"suite-1">>,
        suite_name => <<"unit_tests">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_run_test_suite:handle(Cmd, #{})).
