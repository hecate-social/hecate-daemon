-module(hecate_edge_relay_cache_tests).
-include_lib("eunit/include/eunit.hrl").

setup() ->
    {ok, Pid} = hecate_edge_relay_cache:start_link(),
    Pid.

cleanup(Pid) ->
    catch gen_server:stop(Pid).

new_topic_should_bridge_test() ->
    Pid = setup(),
    ?assertEqual(bridge, hecate_edge_relay_cache:should_bridge(<<"topic.new">>)),
    cleanup(Pid).

bridged_topic_should_skip_test() ->
    Pid = setup(),
    hecate_edge_relay_cache:mark_bridged(<<"topic.cached">>),
    ?assertEqual(skip, hecate_edge_relay_cache:should_bridge(<<"topic.cached">>)),
    cleanup(Pid).

different_topic_still_bridges_test() ->
    Pid = setup(),
    hecate_edge_relay_cache:mark_bridged(<<"topic.a">>),
    ?assertEqual(bridge, hecate_edge_relay_cache:should_bridge(<<"topic.b">>)),
    cleanup(Pid).

invalidate_allows_rebridge_test() ->
    Pid = setup(),
    hecate_edge_relay_cache:mark_bridged(<<"topic.x">>),
    ?assertEqual(skip, hecate_edge_relay_cache:should_bridge(<<"topic.x">>)),
    hecate_edge_relay_cache:invalidate(<<"topic.x">>),
    ?assertEqual(bridge, hecate_edge_relay_cache:should_bridge(<<"topic.x">>)),
    cleanup(Pid).
