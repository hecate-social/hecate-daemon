%%% @doc Tests for node lifecycle projections (event → SQLite writes).
%%%
%%% Uses a temp SQLite database via query_node_lifecycle_store.
%%% Each test group gets a fresh database (foreach pattern).
-module(node_projection_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"identity_registered projects into identities",  fun proj_identity_registered/0},
            {"identity_updated updates metadata",             fun proj_identity_updated/0},
            {"capability_announced projects into capabilities", fun proj_capability_announced/0},
            {"capability_updated updates existing",           fun proj_capability_updated/0},
            {"capability_retracted sets retracted_at",        fun proj_capability_retracted/0},
            {"node_connected projects into connections",      fun proj_node_connected/0},
            {"node_disconnected removes connection",          fun proj_node_disconnected/0},
            {"capability_endorsed projects into endorsements", fun proj_capability_endorsed/0},
            {"endorsement_revoked sets revoked_at",           fun proj_endorsement_revoked/0},
            {"topic_subscribed projects into subscriptions",  fun proj_topic_subscribed/0},
            {"topic_unsubscribed marks inactive",             fun proj_topic_unsubscribed/0},
            {"ucan_granted projects into ucan_grants",        fun proj_ucan_granted/0},
            {"ucan_revoked marks grant as revoked",           fun proj_ucan_revoked/0},
            {"roundtrip: project identity then query",        fun roundtrip_identity/0},
            {"roundtrip: project capability then query",      fun roundtrip_capability/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    TempDir = "/tmp/node_projection_test_" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
    application:set_env(hecate, data_dir, TempDir),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_node_lifecycle_store:start_link(),
    {Pid, TempDir}.

cleanup({Pid, TempDir}) ->
    gen_server:stop(Pid),
    os:cmd("rm -rf " ++ TempDir),
    ok.

%% ===================================================================
%% Identity projection tests
%% ===================================================================

proj_identity_registered() ->
    EventData = #{
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk_abc123">>,
        key_type => <<"ed25519">>,
        metadata => #{role => <<"worker">>},
        registered_at => 1000
    },
    ok = identity_registered_v1_to_identities:project(EventData),
    {ok, Rows} = query_node_lifecycle_store:query(
        "SELECT mri, public_key, key_type, metadata, registered_at FROM identities", []),
    ?assertEqual(1, length(Rows)),
    [[Mri, PubKey, KeyType, _Meta, RegAt]] = Rows,
    ?assertEqual(<<"mri:agent:io.macula/node1">>, Mri),
    ?assertEqual(<<"pk_abc123">>, PubKey),
    ?assertEqual(<<"ed25519">>, KeyType),
    ?assertEqual(1000, RegAt).

proj_identity_updated() ->
    %% First register
    RegData = #{
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk">>,
        key_type => <<"ed25519">>,
        metadata => #{v => <<"1">>},
        registered_at => 1000
    },
    ok = identity_registered_v1_to_identities:project(RegData),
    %% Then update
    UpdData = #{
        mri => <<"mri:agent:io.macula/node1">>,
        metadata => #{v => <<"2">>},
        updated_at => 2000
    },
    ok = identity_updated_v1_to_identities:project(UpdData),
    {ok, [[_Mri, _PK, _KT, MetaJson, _RegAt, UpdAt]]} =
        query_node_lifecycle_store:query(
            "SELECT mri, public_key, key_type, metadata, registered_at, updated_at FROM identities", []),
    ?assertEqual(2000, UpdAt),
    DecodedMeta = json:decode(MetaJson),
    ?assertEqual(<<"2">>, maps:get(<<"v">>, DecodedMeta)).

%% ===================================================================
%% Capability projection tests
%% ===================================================================

proj_capability_announced() ->
    EventData = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"weather">>, <<"forecast">>],
        description => <<"Weather service">>,
        demo_procedure => undefined,
        metadata => #{},
        announced_at => 1000
    },
    ok = capability_announced_v1_to_capabilities:project(EventData),
    {ok, Rows} = query_node_lifecycle_store:query(
        "SELECT mri, agent_id, tags, description, announced_at FROM capabilities", []),
    ?assertEqual(1, length(Rows)),
    [[Mri, AgentId, TagsJson, Desc, AnnAt]] = Rows,
    ?assertEqual(<<"mri:capability:io.macula/weather">>, Mri),
    ?assertEqual(<<"mri:agent:io.macula/node1">>, AgentId),
    ?assertEqual(<<"Weather service">>, Desc),
    ?assertEqual(1000, AnnAt),
    DecodedTags = json:decode(TagsJson),
    ?assertEqual([<<"weather">>, <<"forecast">>], DecodedTags).

proj_capability_updated() ->
    %% First announce
    AnnData = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"weather">>],
        description => <<"v1">>,
        demo_procedure => undefined,
        metadata => #{},
        announced_at => 1000
    },
    ok = capability_announced_v1_to_capabilities:project(AnnData),
    %% Then update
    UpdData = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        tags => [<<"weather">>, <<"updated">>],
        description => <<"v2">>,
        demo_procedure => <<"test.proc">>,
        metadata => #{v => <<"2">>},
        updated_at => 2000
    },
    ok = capability_updated_v1_to_capabilities:project(UpdData),
    {ok, [[_Mri, _AgentId, _Tags, Desc, _Demo, _Meta, _AnnAt, UpdAt, _RetAt]]} =
        query_node_lifecycle_store:query(
            "SELECT mri, agent_id, tags, description, demo_procedure, metadata, "
            "announced_at, updated_at, retracted_at FROM capabilities", []),
    ?assertEqual(<<"v2">>, Desc),
    ?assertEqual(2000, UpdAt).

proj_capability_retracted() ->
    AnnData = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [],
        description => <<"test">>,
        metadata => #{},
        announced_at => 1000
    },
    ok = capability_announced_v1_to_capabilities:project(AnnData),
    RetData = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        retracted_at => 2000
    },
    ok = capability_retracted_v1_to_capabilities:project(RetData),
    {ok, [[RetAt]]} = query_node_lifecycle_store:query(
        "SELECT retracted_at FROM capabilities WHERE mri = ?",
        [<<"mri:capability:io.macula/weather">>]),
    ?assertEqual(2000, RetAt).

%% ===================================================================
%% Connection projection tests
%% ===================================================================

proj_node_connected() ->
    EventData = #{
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node2">>,
        connected_at => 1000
    },
    ok = node_connected_v1_to_connections:project(EventData),
    {ok, Rows} = query_node_lifecycle_store:query(
        "SELECT source_node, target_node, connected_at FROM connections", []),
    ?assertEqual(1, length(Rows)),
    [[Src, Tgt, ConnAt]] = Rows,
    ?assertEqual(<<"mri:agent:io.macula/node1">>, Src),
    ?assertEqual(<<"mri:agent:io.macula/node2">>, Tgt),
    ?assertEqual(1000, ConnAt).

proj_node_disconnected() ->
    %% First connect
    ConnData = #{
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node2">>,
        connected_at => 1000
    },
    ok = node_connected_v1_to_connections:project(ConnData),
    %% Then disconnect
    DiscData = #{
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node2">>
    },
    ok = node_disconnected_v1_to_connections:project(DiscData),
    {ok, Rows} = query_node_lifecycle_store:query(
        "SELECT * FROM connections", []),
    ?assertEqual(0, length(Rows)).

%% ===================================================================
%% Endorsement projection tests
%% ===================================================================

proj_capability_endorsed() ->
    EventData = #{
        endorser_identity => <<"mri:agent:io.macula/endorser1">>,
        capability_mri => <<"mri:capability:io.macula/weather">>,
        comment => <<"Great service">>,
        endorsed_at => 1000
    },
    ok = capability_endorsed_v1_to_endorsements:project(EventData),
    {ok, Rows} = query_node_lifecycle_store:query(
        "SELECT endorser_identity, capability_mri, comment, endorsed_at FROM endorsements", []),
    ?assertEqual(1, length(Rows)),
    [[Endorser, CapMri, Comment, EndAt]] = Rows,
    ?assertEqual(<<"mri:agent:io.macula/endorser1">>, Endorser),
    ?assertEqual(<<"mri:capability:io.macula/weather">>, CapMri),
    ?assertEqual(<<"Great service">>, Comment),
    ?assertEqual(1000, EndAt).

proj_endorsement_revoked() ->
    %% First endorse
    EndData = #{
        endorser_identity => <<"mri:agent:io.macula/endorser1">>,
        capability_mri => <<"mri:capability:io.macula/weather">>,
        comment => <<"test">>,
        endorsed_at => 1000
    },
    ok = capability_endorsed_v1_to_endorsements:project(EndData),
    %% Then revoke
    RevData = #{
        endorser_identity => <<"mri:agent:io.macula/endorser1">>,
        capability_mri => <<"mri:capability:io.macula/weather">>,
        revoked_at => 2000
    },
    ok = endorsement_revoked_v1_to_endorsements:project(RevData),
    {ok, [[RevAt]]} = query_node_lifecycle_store:query(
        "SELECT revoked_at FROM endorsements "
        "WHERE endorser_identity = ? AND capability_mri = ?",
        [<<"mri:agent:io.macula/endorser1">>, <<"mri:capability:io.macula/weather">>]),
    ?assertEqual(2000, RevAt).

%% ===================================================================
%% Subscription projection tests
%% ===================================================================

proj_topic_subscribed() ->
    EventData = #{
        agent_identity => <<"mri:agent:io.macula/node1">>,
        topic => <<"events.weather">>,
        filter => undefined,
        subscribed_at => 1000
    },
    ok = topic_subscribed_v1_to_subscriptions:project(EventData),
    {ok, Rows} = query_node_lifecycle_store:query(
        "SELECT agent_identity, topic, active FROM subscriptions", []),
    ?assertEqual(1, length(Rows)),
    [[Agent, Topic, Active]] = Rows,
    ?assertEqual(<<"mri:agent:io.macula/node1">>, Agent),
    ?assertEqual(<<"events.weather">>, Topic),
    ?assertEqual(1, Active).

proj_topic_unsubscribed() ->
    %% First subscribe
    SubData = #{
        agent_identity => <<"mri:agent:io.macula/node1">>,
        topic => <<"events.weather">>,
        filter => undefined,
        subscribed_at => 1000
    },
    ok = topic_subscribed_v1_to_subscriptions:project(SubData),
    %% Then unsubscribe
    UnsubData = #{
        agent_identity => <<"mri:agent:io.macula/node1">>,
        topic => <<"events.weather">>
    },
    ok = topic_unsubscribed_v1_to_subscriptions:project(UnsubData),
    {ok, [[Active]]} = query_node_lifecycle_store:query(
        "SELECT active FROM subscriptions "
        "WHERE agent_identity = ? AND topic = ?",
        [<<"mri:agent:io.macula/node1">>, <<"events.weather">>]),
    ?assertEqual(0, Active).

%% ===================================================================
%% UCAN projection tests
%% ===================================================================

proj_ucan_granted() ->
    EventData = #{
        capability_id => <<"cap-001">>,
        issuer => <<"mri:agent:io.macula/node1">>,
        audience => <<"mri:agent:io.macula/node2">>,
        resource => <<"mri:capability:io.macula/weather">>,
        actions => [<<"read">>, <<"write">>],
        expires_at => 99999,
        granted_at => 1000
    },
    ok = ucan_granted_v1_to_ucan_grants:project(EventData),
    {ok, Rows} = query_node_lifecycle_store:query(
        "SELECT capability_id, issuer, audience, resource, actions, "
        "expires_at, granted_at, revoked FROM ucan_grants", []),
    ?assertEqual(1, length(Rows)),
    [[CapId, Issuer, Audience, Resource, ActionsJson, ExpiresAt, GrantedAt, Revoked]] = Rows,
    ?assertEqual(<<"cap-001">>, CapId),
    ?assertEqual(<<"mri:agent:io.macula/node1">>, Issuer),
    ?assertEqual(<<"mri:agent:io.macula/node2">>, Audience),
    ?assertEqual(<<"mri:capability:io.macula/weather">>, Resource),
    ?assertEqual(99999, ExpiresAt),
    ?assertEqual(1000, GrantedAt),
    ?assertEqual(0, Revoked),
    DecodedActions = json:decode(ActionsJson),
    ?assertEqual([<<"read">>, <<"write">>], DecodedActions).

proj_ucan_revoked() ->
    %% First grant
    GrantData = #{
        capability_id => <<"cap-001">>,
        issuer => <<"mri:agent:io.macula/node1">>,
        audience => <<"mri:agent:io.macula/node2">>,
        resource => <<"mri:capability:io.macula/weather">>,
        actions => [<<"read">>],
        expires_at => 99999,
        granted_at => 1000
    },
    ok = ucan_granted_v1_to_ucan_grants:project(GrantData),
    %% Then revoke
    RevokeData = #{
        capability_id => <<"cap-001">>,
        revoked_at => 2000
    },
    ok = ucan_revoked_v1_to_ucan_grants:project(RevokeData),
    {ok, [[Revoked, RevokedAt]]} = query_node_lifecycle_store:query(
        "SELECT revoked, revoked_at FROM ucan_grants WHERE capability_id = ?",
        [<<"cap-001">>]),
    ?assertEqual(1, Revoked),
    ?assertEqual(2000, RevokedAt).

%% ===================================================================
%% Roundtrip tests: project → query via query desk modules
%% ===================================================================

roundtrip_identity() ->
    EventData = #{
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk_roundtrip">>,
        key_type => <<"secp256k1">>,
        metadata => #{purpose => <<"test">>},
        registered_at => 5000
    },
    ok = identity_registered_v1_to_identities:project(EventData),
    {ok, [Identity]} = get_identities_page:get(#{limit => 10, offset => 0}),
    ?assertEqual(<<"mri:agent:io.macula/node1">>, maps:get(mri, Identity)),
    ?assertEqual(<<"pk_roundtrip">>, maps:get(public_key, Identity)),
    ?assertEqual(<<"secp256k1">>, maps:get(key_type, Identity)).

roundtrip_capability() ->
    EventData = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"weather">>],
        description => <<"Weather service">>,
        demo_procedure => undefined,
        metadata => #{},
        announced_at => 3000
    },
    ok = capability_announced_v1_to_capabilities:project(EventData),
    {ok, [Cap]} = get_capabilities_page:get(#{limit => 10, offset => 0}),
    ?assertEqual(<<"mri:capability:io.macula/weather">>, maps:get(mri, Cap)),
    ?assertEqual(<<"mri:agent:io.macula/node1">>, maps:get(agent_id, Cap)),
    ?assertEqual(<<"Weather service">>, maps:get(description, Cap)).
