%%% @doc Tests for design_aggregate desk handler validation logic (DnA phase).
%%%
%%% Tests maybe_design_aggregate:handle/2 and design_aggregate_v1 command.
%%% Pure function tests — no external deps.
-module(design_aggregate_desk_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

design_aggregate_desk_test_() ->
    [
        {"valid: all fields produce event",             fun valid_all_fields/0},
        {"duplicate_rejected: same name in context",    fun duplicate_rejected/0},
        {"empty_division_id: validation error",         fun empty_division_id/0},
        {"empty_aggregate_name: validation error",      fun empty_aggregate_name/0},
        {"event_fields: to_map has all expected keys",  fun event_fields/0}
    ].

%% ===================================================================
%% Tests
%% ===================================================================

valid_all_fields() ->
    {ok, Cmd} = design_aggregate_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"order">>,
        description => <<"Order aggregate">>,
        stream_prefix => <<"order-">>,
        fields => [<<"id">>, <<"status">>]
    }),
    Context = #{designed_aggregates => #{}},
    {ok, [Event]} = maybe_design_aggregate:handle(Cmd, Context),
    Map = aggregate_designed_v1:to_map(Event),
    ?assertEqual(<<"aggregate_designed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"order">>, maps:get(<<"aggregate_name">>, Map)).

duplicate_rejected() ->
    {ok, Cmd} = design_aggregate_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"order">>,
        description => <<"Order aggregate">>,
        stream_prefix => <<"order-">>,
        fields => [<<"id">>, <<"status">>]
    }),
    Context = #{designed_aggregates => #{<<"order">> => #{}}},
    ?assertEqual({error, aggregate_already_designed},
                 maybe_design_aggregate:handle(Cmd, Context)).

empty_division_id() ->
    {ok, Cmd} = design_aggregate_v1:new(#{
        division_id => <<>>,
        aggregate_name => <<"order">>,
        description => <<"Order aggregate">>
    }),
    ?assertMatch({error, invalid_division_id},
                 maybe_design_aggregate:handle(Cmd, #{designed_aggregates => #{}})).

empty_aggregate_name() ->
    {ok, Cmd} = design_aggregate_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<>>,
        description => <<"Order aggregate">>
    }),
    ?assertMatch({error, invalid_aggregate_name},
                 maybe_design_aggregate:handle(Cmd, #{designed_aggregates => #{}})).

event_fields() ->
    {ok, Cmd} = design_aggregate_v1:new(#{
        division_id => <<"div-1">>,
        aggregate_name => <<"order">>,
        description => <<"Order aggregate">>,
        stream_prefix => <<"order-">>,
        fields => [<<"id">>, <<"status">>]
    }),
    {ok, [Event]} = maybe_design_aggregate:handle(Cmd, #{designed_aggregates => #{}}),
    Map = aggregate_designed_v1:to_map(Event),
    ?assertEqual(<<"aggregate_designed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"order">>, maps:get(<<"aggregate_name">>, Map)),
    ?assertEqual(<<"Order aggregate">>, maps:get(<<"description">>, Map)),
    ?assertEqual(<<"order-">>, maps:get(<<"stream_prefix">>, Map)),
    ?assertEqual([<<"id">>, <<"status">>], maps:get(<<"fields">>, Map)),
    ?assert(is_integer(maps:get(<<"designed_at">>, Map))).
