%%% @doc Tests for design_event desk handler validation logic (DnA phase).
%%%
%%% Tests maybe_design_event:handle/2 and design_event_v1 command.
%%% Pure function tests — no external deps.
-module(design_event_desk_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

design_event_desk_test_() ->
    [
        {"valid: all fields produce event",            fun valid_all_fields/0},
        {"duplicate_rejected: same name in context",   fun duplicate_rejected/0},
        {"empty_division_id: validation error",        fun empty_division_id/0},
        {"empty_event_name: validation error",         fun empty_event_name/0}
    ].

%% ===================================================================
%% Tests
%% ===================================================================

valid_all_fields() ->
    {ok, Cmd} = design_event_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        description => <<"Placed">>,
        aggregate_name => <<"order">>,
        fields => [<<"order_id">>]
    }),
    Context = #{designed_events => #{}},
    {ok, [Event]} = maybe_design_event:handle(Cmd, Context),
    Map = event_designed_v1:to_map(Event),
    ?assertEqual(<<"event_designed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"order_placed_v1">>, maps:get(<<"event_name">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"Placed">>, maps:get(<<"description">>, Map)),
    ?assertEqual(<<"order">>, maps:get(<<"aggregate_name">>, Map)),
    ?assertEqual([<<"order_id">>], maps:get(<<"fields">>, Map)),
    ?assert(is_integer(maps:get(<<"designed_at">>, Map))).

duplicate_rejected() ->
    {ok, Cmd} = design_event_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<"order_placed_v1">>,
        description => <<"Placed">>,
        aggregate_name => <<"order">>,
        fields => [<<"order_id">>]
    }),
    Context = #{designed_events => #{<<"order_placed_v1">> => #{}}},
    ?assertEqual({error, event_already_designed},
                 maybe_design_event:handle(Cmd, Context)).

empty_division_id() ->
    {ok, Cmd} = design_event_v1:new(#{
        division_id => <<>>,
        event_name => <<"order_placed_v1">>,
        description => <<"Placed">>
    }),
    ?assertMatch({error, invalid_division_id},
                 maybe_design_event:handle(Cmd, #{designed_events => #{}})).

empty_event_name() ->
    {ok, Cmd} = design_event_v1:new(#{
        division_id => <<"div-1">>,
        event_name => <<>>,
        description => <<"Placed">>
    }),
    ?assertMatch({error, invalid_event_name},
                 maybe_design_event:handle(Cmd, #{designed_events => #{}})).
