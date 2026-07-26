%%% @doc EUnit tests for receive_mesh_fact_listener.
%%%
%%% Covers: self-publish drop, malformed-payload drop, dispatch on
%%% valid non-self payload. hecate_identity and maybe_receive_mesh_fact
%%% are mocked via meck.
%%% @end
-module(receive_mesh_fact_listener_tests).

-include_lib("eunit/include/eunit.hrl").

-define(SELF_ID, <<"self-pubkey-32-bytes-AAAAAAAAAAAA">>).
-define(OTHER_ID, <<"peer-pubkey-32-bytes-BBBBBBBBBBBB">>).
-define(TOPIC, <<"chat.demo">>).

%%--------------------------------------------------------------------
%% Setup / teardown
%%--------------------------------------------------------------------

listener_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     [
        {"non-self publish dispatches a receive_mesh_fact command",
         fun non_self_publish_dispatches/0},
        {"self publish is silently dropped",
         fun self_publish_is_dropped/0},
        {"non-map payload is dropped without dispatch",
         fun non_map_payload_dropped/0},
        {"meta without publisher dispatches with sender_node_id=undefined",
         fun missing_publisher_still_dispatches/0}
     ]}.

setup() ->
    meck:new(hecate_identity, [non_strict]),
    meck:expect(hecate_identity, agent_id, 0, fun() -> {ok, ?SELF_ID} end),
    meck:new(maybe_receive_mesh_fact, [non_strict, passthrough]),
    meck:expect(maybe_receive_mesh_fact, dispatch, 1,
                fun(_Cmd) -> {ok, 1, []} end),
    ok.

cleanup(_) ->
    meck:unload(maybe_receive_mesh_fact),
    meck:unload(hecate_identity),
    ok.

%%--------------------------------------------------------------------
%% Tests
%%--------------------------------------------------------------------

non_self_publish_dispatches() ->
    meck:reset(maybe_receive_mesh_fact),
    Meta = #{publisher => ?OTHER_ID, realm => <<0:256>>, seq => 1},
    ok = receive_mesh_fact_listener:on_fact(?TOPIC, #{text => <<"hello">>}, Meta),
    ?assert(wait_for_calls(maybe_receive_mesh_fact, dispatch, 1, 500)),
    %% Inspect the command that was dispatched.
    [{_, {_, _, [Cmd]}, _}] = meck:history(maybe_receive_mesh_fact),
    Map = receive_mesh_fact_v1:to_map(Cmd),
    ?assertEqual(?TOPIC, maps:get(topic, Map)),
    ?assertEqual(?OTHER_ID, maps:get(sender_node_id, Map)),
    ?assertEqual(true, maps:get(sig_verified, Map)).

self_publish_is_dropped() ->
    meck:reset(maybe_receive_mesh_fact),
    Meta = #{publisher => ?SELF_ID, realm => <<0:256>>, seq => 1},
    ok = receive_mesh_fact_listener:on_fact(?TOPIC, #{text => <<"loop">>}, Meta),
    %% Give any (incorrectly-spawned) worker a chance to run.
    timer:sleep(50),
    ?assertEqual(0, meck:num_calls(maybe_receive_mesh_fact, dispatch, 1)).

non_map_payload_dropped() ->
    meck:reset(maybe_receive_mesh_fact),
    Meta = #{publisher => ?OTHER_ID, realm => <<0:256>>, seq => 1},
    ok = receive_mesh_fact_listener:on_fact(?TOPIC, <<"raw-bytes">>, Meta),
    timer:sleep(50),
    ?assertEqual(0, meck:num_calls(maybe_receive_mesh_fact, dispatch, 1)).

missing_publisher_still_dispatches() ->
    meck:reset(maybe_receive_mesh_fact),
    Meta = #{realm => <<0:256>>, seq => 1},
    ok = receive_mesh_fact_listener:on_fact(?TOPIC, #{text => <<"hi">>}, Meta),
    ?assert(wait_for_calls(maybe_receive_mesh_fact, dispatch, 1, 500)),
    [{_, {_, _, [Cmd]}, _}] = meck:history(maybe_receive_mesh_fact),
    Map = receive_mesh_fact_v1:to_map(Cmd),
    ?assertEqual(undefined, maps:get(sender_node_id, Map)),
    ?assertEqual(false, maps:get(sig_verified, Map)).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

%% Poll until meck records >= 1 call for the function, or timeout.
wait_for_calls(Mod, Fun, Arity, TimeoutMs) ->
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    wait_loop(Mod, Fun, Arity, Deadline).

wait_loop(Mod, Fun, Arity, Deadline) ->
    case meck:num_calls(Mod, Fun, Arity) of
        N when N >= 1 -> true;
        _ ->
            case erlang:monotonic_time(millisecond) of
                T when T >= Deadline -> false;
                _ -> timer:sleep(10), wait_loop(Mod, Fun, Arity, Deadline)
            end
    end.
