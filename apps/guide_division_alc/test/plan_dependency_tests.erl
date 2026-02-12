%%% @doc Tests for plan_dependency handler validation logic (AnP phase).
%%%
%%% Tests maybe_plan_dependency:handle/2 and plan_dependency_v1 command.
%%% Pure function tests — no external deps.
-module(plan_dependency_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

plan_dependency_test_() ->
    [
        {"valid: all fields produce event",              fun valid_all_fields/0},
        {"duplicate_rejected: same dep_id in context",   fun duplicate_rejected/0},
        {"empty_division_id: validation error",          fun empty_division_id/0}
    ].

%% ===================================================================
%% Tests
%% ===================================================================

valid_all_fields() ->
    {ok, Cmd} = plan_dependency_v1:new(#{
        division_id => <<"div-1">>,
        dependency_id => <<"dep-1">>,
        from_desk => <<"place_order">>,
        to_desk => <<"notify">>,
        dep_type => <<"event">>
    }),
    Context = #{planned_dependencies => #{}},
    {ok, [Event]} = maybe_plan_dependency:handle(Cmd, Context),
    Map = dependency_planned_v1:to_map(Event),
    ?assertEqual(<<"dependency_planned_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"dep-1">>, maps:get(<<"dependency_id">>, Map)),
    ?assertEqual(<<"place_order">>, maps:get(<<"from_desk">>, Map)),
    ?assertEqual(<<"notify">>, maps:get(<<"to_desk">>, Map)),
    ?assertEqual(<<"event">>, maps:get(<<"dep_type">>, Map)),
    ?assert(is_integer(maps:get(<<"planned_at">>, Map))).

duplicate_rejected() ->
    {ok, Cmd} = plan_dependency_v1:new(#{
        division_id => <<"div-1">>,
        dependency_id => <<"dep-1">>,
        from_desk => <<"place_order">>,
        to_desk => <<"notify">>,
        dep_type => <<"event">>
    }),
    Context = #{planned_dependencies => #{<<"dep-1">> => #{}}},
    ?assertEqual({error, dependency_already_planned},
                 maybe_plan_dependency:handle(Cmd, Context)).

empty_division_id() ->
    {ok, Cmd} = plan_dependency_v1:new(#{
        division_id => <<>>,
        dependency_id => <<"dep-1">>,
        from_desk => <<"place_order">>,
        to_desk => <<"notify">>,
        dep_type => <<"event">>
    }),
    ?assertMatch({error, invalid_division_id},
                 maybe_plan_dependency:handle(Cmd, #{planned_dependencies => #{}})).
