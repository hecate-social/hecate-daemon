%%% @doc Tests for maybe_generate_module handler and generate_module_v1 command.
%%% Covers valid generation, duplicate detection, and empty division_id rejection.
-module(generate_module_tests).

-include_lib("eunit/include/eunit.hrl").

generate_module_test_() ->
    [
        {"valid: handler returns event with module_name", fun valid_generate_module/0},
        {"duplicate: rejects already generated module",   fun duplicate_module/0},
        {"empty_division_id: command rejected",           fun empty_division_id/0}
    ].

valid_generate_module() ->
    {ok, Cmd} = generate_module_v1:new(#{
        division_id => <<"div-1">>,
        module_name => <<"place_order_v1">>,
        module_type => <<"command">>,
        path => <<"src/place_order_v1.erl">>
    }),
    Context = #{generated_modules => #{}},
    {ok, [Event]} = maybe_generate_module:handle(Cmd, Context),
    Map = module_generated_v1:to_map(Event),
    ?assertEqual(<<"place_order_v1">>, maps:get(<<"module_name">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"module_generated_v1">>, maps:get(<<"event_type">>, Map)).

duplicate_module() ->
    {ok, Cmd} = generate_module_v1:new(#{
        division_id => <<"div-1">>,
        module_name => <<"place_order_v1">>,
        module_type => <<"command">>,
        path => <<"src/place_order_v1.erl">>
    }),
    Context = #{generated_modules => #{<<"place_order_v1">> => #{}}},
    ?assertEqual({error, module_already_generated},
                 maybe_generate_module:handle(Cmd, Context)).

empty_division_id() ->
    {ok, Cmd} = generate_module_v1:new(#{
        division_id => <<>>,
        module_name => <<"place_order_v1">>,
        module_type => <<"command">>,
        path => <<"src/place_order_v1.erl">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_generate_module:handle(Cmd, #{})).
