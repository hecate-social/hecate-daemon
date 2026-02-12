%%% @doc Tests for plan_desk handler validation logic (AnP phase).
%%%
%%% Tests maybe_plan_desk:handle/2 and plan_desk_v1 command.
%%% Pure function tests — no external deps.
-module(plan_desk_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

plan_desk_test_() ->
    [
        {"valid: all fields produce event",            fun valid_all_fields/0},
        {"duplicate_rejected: same name in context",   fun duplicate_rejected/0},
        {"empty_division_id: validation error",        fun empty_division_id/0},
        {"empty_desk_name: validation error",          fun empty_desk_name/0}
    ].

%% ===================================================================
%% Tests
%% ===================================================================

valid_all_fields() ->
    {ok, Cmd} = plan_desk_v1:new(#{
        division_id => <<"div-1">>,
        desk_name => <<"place_order">>,
        description => <<"Place order">>,
        department => <<"cmd">>,
        commands => [<<"place_order_v1">>]
    }),
    Context = #{planned_desks => #{}},
    {ok, [Event]} = maybe_plan_desk:handle(Cmd, Context),
    Map = desk_planned_v1:to_map(Event),
    ?assertEqual(<<"desk_planned_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"place_order">>, maps:get(<<"desk_name">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"Place order">>, maps:get(<<"description">>, Map)),
    ?assertEqual(<<"cmd">>, maps:get(<<"department">>, Map)),
    ?assertEqual([<<"place_order_v1">>], maps:get(<<"commands">>, Map)),
    ?assert(is_integer(maps:get(<<"planned_at">>, Map))).

duplicate_rejected() ->
    {ok, Cmd} = plan_desk_v1:new(#{
        division_id => <<"div-1">>,
        desk_name => <<"place_order">>,
        description => <<"Place order">>,
        department => <<"cmd">>,
        commands => [<<"place_order_v1">>]
    }),
    Context = #{planned_desks => #{<<"place_order">> => #{}}},
    ?assertEqual({error, desk_already_planned},
                 maybe_plan_desk:handle(Cmd, Context)).

empty_division_id() ->
    {ok, Cmd} = plan_desk_v1:new(#{
        division_id => <<>>,
        desk_name => <<"place_order">>,
        description => <<"Place order">>
    }),
    ?assertMatch({error, invalid_division_id},
                 maybe_plan_desk:handle(Cmd, #{planned_desks => #{}})).

empty_desk_name() ->
    {ok, Cmd} = plan_desk_v1:new(#{
        division_id => <<"div-1">>,
        desk_name => <<>>,
        description => <<"Place order">>
    }),
    ?assertMatch({error, invalid_desk_name},
                 maybe_plan_desk:handle(Cmd, #{planned_desks => #{}})).
