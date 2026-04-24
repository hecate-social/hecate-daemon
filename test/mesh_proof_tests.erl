%%%-------------------------------------------------------------------
%%% @doc Tests for mesh proof protocol.
%%%
%%% Tests probe modules with mocked macula calls and the coordinator
%%% state machine with mocked dependencies.
%%% @end
%%%-------------------------------------------------------------------
-module(mesh_proof_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Probe Tests
%%====================================================================

probe_dht_test_() ->
    {foreach,
        fun setup_macula_mock/0,
        fun cleanup_macula_mock/1,
        [
            {"dht probe returns node_id and peer_count",
             fun dht_returns_node_info/0},
            {"dht probe reports solo_node when no peers",
             fun dht_solo_node/0},
            {"dht probe fails when no node_id",
             fun dht_no_node_id/0}
        ]
    }.

dht_returns_node_info() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    FakePeers = [<<"peer1">>, <<"peer2">>, <<"peer3">>],
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, get_known_peers, fun(_Client) -> {ok, FakePeers} end),

    {ok, Detail} = probe_mesh_dht:run(self()),

    ?assertEqual(binary:encode_hex(FakeNodeId), maps:get(node_id, Detail)),
    ?assertEqual(3, maps:get(peer_count, Detail)),
    ?assertEqual(false, maps:get(solo_node, Detail)).

dht_solo_node() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, get_known_peers, fun(_Client) -> {ok, []} end),

    {ok, Detail} = probe_mesh_dht:run(self()),

    ?assertEqual(0, maps:get(peer_count, Detail)),
    ?assertEqual(true, maps:get(solo_node, Detail)).

dht_no_node_id() ->
    meck:expect(macula, get_node_id, fun(_Client) -> {error, not_ready} end),

    Result = probe_mesh_dht:run(self()),

    ?assertMatch({error, {no_node_id, not_ready}}, Result).

probe_pubsub_test_() ->
    {foreach,
        fun setup_macula_mock/0,
        fun cleanup_macula_mock/1,
        [
            {"pubsub probe succeeds on round-trip",
             fun pubsub_round_trip/0},
            {"pubsub probe fails on subscribe error",
             fun pubsub_subscribe_fails/0},
            {"pubsub probe fails on publish error",
             fun pubsub_publish_fails/0}
        ]
    }.

pubsub_round_trip() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),

    %% Subscribe captures the callback, then we simulate receiving the message
    TestPid = self(),
    meck:expect(macula, subscribe, fun(_Client, _Topic, Callback) ->
        %% Store callback so we can invoke it after publish
        put(captured_callback, Callback),
        {ok, make_ref()}
    end),
    meck:expect(macula, publish, fun(_Client, _Topic, Payload) ->
        %% Simulate the mesh echoing back by invoking the captured callback
        Callback = get(captured_callback),
        spawn(fun() ->
            %% Convert atom keys to binary keys (as mesh would)
            BinPayload = maps:from_list([{atom_to_binary(K), V}
                                          || {K, V} <- maps:to_list(Payload)]),
            Callback(BinPayload)
        end),
        ok
    end),
    meck:expect(macula, unsubscribe, fun(_Client, _SubRef) -> ok end),

    {ok, Detail} = probe_mesh_pubsub:run(TestPid),

    ?assert(is_integer(maps:get(round_trip_ms, Detail))),
    ?assert(maps:get(round_trip_ms, Detail) >= 0).

pubsub_subscribe_fails() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, subscribe, fun(_Client, _Topic, _Cb) ->
        {error, not_connected}
    end),

    Result = probe_mesh_pubsub:run(self()),

    ?assertMatch({error, {subscribe_failed, not_connected}}, Result).

pubsub_publish_fails() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, subscribe, fun(_Client, _Topic, _Cb) ->
        {ok, make_ref()}
    end),
    meck:expect(macula, publish, fun(_Client, _Topic, _Payload) ->
        {error, connection_lost}
    end),
    meck:expect(macula, unsubscribe, fun(_Client, _SubRef) -> ok end),

    Result = probe_mesh_pubsub:run(self()),

    ?assertMatch({error, {publish_failed, connection_lost}}, Result).

probe_rpc_test_() ->
    {foreach,
        fun setup_macula_mock/0,
        fun cleanup_macula_mock/1,
        [
            {"rpc probe succeeds on echo",
             fun rpc_echo_succeeds/0},
            {"rpc probe fails on advertise error",
             fun rpc_advertise_fails/0},
            {"rpc probe fails on nonce mismatch",
             fun rpc_nonce_mismatch/0}
        ]
    }.

rpc_echo_succeeds() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),

    %% Advertise captures handler, call invokes it
    meck:expect(macula, advertise, fun(_Client, _Proc, Handler) ->
        put(captured_handler, Handler),
        {ok, make_ref()}
    end),
    meck:expect(macula, call, fun(_Client, _Proc, Args) ->
        Handler = get(captured_handler),
        Handler(Args)
    end),
    meck:expect(macula, unadvertise, fun(_Client, _Ref) -> ok end),

    {ok, Detail} = probe_mesh_rpc:run(self()),

    ?assert(is_integer(maps:get(round_trip_ms, Detail))).

rpc_advertise_fails() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, advertise, fun(_Client, _Proc, _Handler) ->
        {error, not_connected}
    end),

    Result = probe_mesh_rpc:run(self()),

    ?assertMatch({error, {advertise_failed, not_connected}}, Result).

rpc_nonce_mismatch() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, advertise, fun(_Client, _Proc, _Handler) ->
        {ok, make_ref()}
    end),
    meck:expect(macula, call, fun(_Client, _Proc, _Args) ->
        {ok, #{echo => <<"wrong_nonce">>}}
    end),
    meck:expect(macula, unadvertise, fun(_Client, _Ref) -> ok end),

    Result = probe_mesh_rpc:run(self()),

    ?assertMatch({error, {nonce_mismatch, _}}, Result).

probe_content_test_() ->
    {foreach,
        fun setup_macula_content_mock/0,
        fun cleanup_macula_content_mock/1,
        [
            {"content probe succeeds on store+fetch",
             fun content_round_trip/0},
            {"content probe fails on store error",
             fun content_store_fails/0},
            {"content probe detects content mismatch",
             fun content_mismatch/0}
        ]
    }.

content_round_trip() ->
    FakeManifest = #{chunks => [<<"chunk1">>]},
    meck:expect(macula_content, store, fun(_Payload) ->
        {ok, FakeManifest}
    end),
    meck:expect(macula_content, mcid, fun(Payload) ->
        crypto:hash(sha256, Payload)
    end),
    meck:expect(macula_content, fetch, fun(_MCID) ->
        %% We need to return the same payload that was stored.
        %% Since the probe generates a random payload, we capture it.
        %% The mock for store already ran, so we stored whatever was passed.
        %% For this test, we trust the round-trip by returning what was stored.
        {ok, get(stored_payload)}
    end),
    meck:expect(macula_content, mcid_to_string, fun(MCID) ->
        <<"mcid1-", (binary:encode_hex(MCID))/binary>>
    end),
    meck:expect(macula_content, get_chunks, fun(_Manifest) ->
        [<<"chunk1">>]
    end),

    %% Capture the stored payload
    meck:expect(macula_content, store, fun(Payload) ->
        put(stored_payload, Payload),
        {ok, FakeManifest}
    end),

    {ok, Detail} = probe_mesh_content:run(self()),

    ?assert(is_binary(maps:get(mcid, Detail))),
    ?assert(is_integer(maps:get(round_trip_ms, Detail))),
    ?assert(maps:get(size, Detail) > 0).

content_store_fails() ->
    meck:expect(macula_content, store, fun(_Payload) ->
        {error, disk_full}
    end),

    Result = probe_mesh_content:run(self()),

    ?assertMatch({error, {store_failed, disk_full}}, Result).

content_mismatch() ->
    FakeManifest = #{chunks => []},
    meck:expect(macula_content, store, fun(_Payload) ->
        {ok, FakeManifest}
    end),
    meck:expect(macula_content, mcid, fun(Payload) ->
        crypto:hash(sha256, Payload)
    end),
    meck:expect(macula_content, fetch, fun(_MCID) ->
        {ok, <<"totally_different_data">>}
    end),

    Result = probe_mesh_content:run(self()),

    ?assertMatch({error, content_mismatch}, Result).

%%====================================================================
%% Coordinator Tests
%%====================================================================

coordinator_test_() ->
    {foreach,
        fun setup_coordinator/0,
        fun cleanup_coordinator/1,
        [
            {"starts in pending state",
             fun coordinator_starts_pending/0},
            {"get_proof_results returns current state",
             fun coordinator_returns_results/0}
        ]
    }.

coordinator_starts_pending() ->
    Result = mesh_proof_coordinator:get_proof_results(),

    ?assertEqual(pending, maps:get(proof_status, Result)),
    ?assertEqual(#{}, maps:get(probes, Result)),
    ?assertEqual(true, maps:get(ok, Result)).

coordinator_returns_results() ->
    Result = mesh_proof_coordinator:get_proof_results(),

    ?assert(maps:is_key(proof_status, Result)),
    ?assert(maps:is_key(probes, Result)),
    ?assert(maps:is_key(elapsed_ms, Result)),
    ?assert(maps:is_key(presence, Result)).

%%====================================================================
%% Announce Tests
%%====================================================================

announce_test_() ->
    {foreach,
        fun setup_announce_mock/0,
        fun cleanup_announce_mock/1,
        [
            {"announces presence with capabilities",
             fun announce_with_capabilities/0},
            {"handles publish failure gracefully",
             fun announce_publish_fails/0}
        ]
    }.

announce_with_capabilities() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, get_known_peers, fun(_Client) -> {ok, [<<"peer1">>]} end),
    meck:expect(macula, list_nodes, fun(_Client) -> {ok, #{<<"peer1">> => #{}}} end),

    CaptureRef = make_ref(),
    TestPid = self(),
    meck:expect(macula, publish, fun(_Client, Topic, Payload) ->
        TestPid ! {CaptureRef, Topic, Payload},
        ok
    end),

    ProbeResults = #{
        pubsub => #{status => passed},
        rpc => #{status => passed},
        dht => #{status => failed},
        content => #{status => passed}
    },

    ok = announce_mesh_presence:announce(self(), ProbeResults),

    receive
        {CaptureRef, Topic, Payload} ->
            %% Topic is {realm}/beam-campus/hecate/presence/announced_v1
            ExpectedTopic = hecate_topics:app_fact(<<"presence">>, <<"announced">>, 1),
            ?assertEqual(ExpectedTopic, Topic),
            ?assert(is_list(maps:get(capabilities, Payload))),
            Caps = maps:get(capabilities, Payload),
            ?assert(lists:member(pubsub, Caps)),
            ?assert(lists:member(rpc, Caps)),
            ?assertNot(lists:member(dht, Caps)),
            ?assert(lists:member(content, Caps))
    after 1000 ->
        ?assert(false)
    end.

announce_publish_fails() ->
    FakeNodeId = crypto:strong_rand_bytes(32),
    meck:expect(macula, get_node_id, fun(_Client) -> {ok, FakeNodeId} end),
    meck:expect(macula, publish, fun(_Client, _Topic, _Payload) ->
        {error, not_connected}
    end),

    Result = announce_mesh_presence:announce(self(), #{}),

    ?assertMatch({error, not_connected}, Result).

%%====================================================================
%% Setup / Cleanup Helpers
%%====================================================================

setup_macula_mock() ->
    meck:new(macula, [non_strict]),
    ok.

cleanup_macula_mock(_) ->
    meck:unload(macula),
    ok.

setup_macula_content_mock() ->
    meck:new(macula_content, [non_strict]),
    ok.

cleanup_macula_content_mock(_) ->
    meck:unload(macula_content),
    ok.

setup_coordinator() ->
    %% Start pg scope if not running
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end,
    {ok, Pid} = mesh_proof_coordinator:start_link(),
    Pid.

cleanup_coordinator(Pid) ->
    gen_server:stop(Pid),
    ok.

setup_announce_mock() ->
    meck:new(macula, [non_strict]),
    %% Mock pg to avoid needing the group
    ok.

cleanup_announce_mock(_) ->
    meck:unload(macula),
    ok.
