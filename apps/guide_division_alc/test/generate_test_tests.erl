%%% @doc Tests for maybe_generate_test handler and generate_test_v1 command.
%%% Covers valid generation, duplicate detection, and empty division_id rejection.
-module(generate_test_tests).

-include_lib("eunit/include/eunit.hrl").

generate_test_test_() ->
    [
        {"valid: handler returns event with test_name", fun valid_generate_test/0},
        {"duplicate: rejects already generated test",   fun duplicate_test/0},
        {"empty_division_id: command rejected",         fun empty_division_id/0}
    ].

valid_generate_test() ->
    {ok, Cmd} = generate_test_v1:new(#{
        division_id => <<"div-1">>,
        test_name => <<"order_tests">>,
        module_name => <<"order">>,
        path => <<"test/order_tests.erl">>
    }),
    Context = #{generated_tests => #{}},
    {ok, [Event]} = maybe_generate_test:handle(Cmd, Context),
    Map = test_generated_v1:to_map(Event),
    ?assertEqual(<<"order_tests">>, maps:get(<<"test_name">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"test_generated_v1">>, maps:get(<<"event_type">>, Map)).

duplicate_test() ->
    {ok, Cmd} = generate_test_v1:new(#{
        division_id => <<"div-1">>,
        test_name => <<"order_tests">>,
        module_name => <<"order">>,
        path => <<"test/order_tests.erl">>
    }),
    Context = #{generated_tests => #{<<"order_tests">> => #{}}},
    ?assertEqual({error, test_already_generated},
                 maybe_generate_test:handle(Cmd, Context)).

empty_division_id() ->
    {ok, Cmd} = generate_test_v1:new(#{
        division_id => <<>>,
        test_name => <<"order_tests">>,
        module_name => <<"order">>,
        path => <<"test/order_tests.erl">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_generate_test:handle(Cmd, #{})).
