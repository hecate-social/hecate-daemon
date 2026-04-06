-module(mesh_catch_up_tests).
-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Position tracking tests
%%====================================================================

init_position_table_test() ->
    mesh_catch_up:init_position_table(),
    %% Should be idempotent
    mesh_catch_up:init_position_table(),
    ok.

default_position_is_zero_test() ->
    mesh_catch_up:init_position_table(),
    ?assertEqual(0, mesh_catch_up:get_position(<<"new_stream">>)).

save_and_get_position_test() ->
    mesh_catch_up:init_position_table(),
    mesh_catch_up:save_position(<<"stream_a">>, 42),
    ?assertEqual(42, mesh_catch_up:get_position(<<"stream_a">>)).

position_update_overwrites_test() ->
    mesh_catch_up:init_position_table(),
    mesh_catch_up:save_position(<<"stream_b">>, 10),
    mesh_catch_up:save_position(<<"stream_b">>, 20),
    ?assertEqual(20, mesh_catch_up:get_position(<<"stream_b">>)).

independent_streams_test() ->
    mesh_catch_up:init_position_table(),
    mesh_catch_up:save_position(<<"s1">>, 100),
    mesh_catch_up:save_position(<<"s2">>, 200),
    ?assertEqual(100, mesh_catch_up:get_position(<<"s1">>)),
    ?assertEqual(200, mesh_catch_up:get_position(<<"s2">>)).
