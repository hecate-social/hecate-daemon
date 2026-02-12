%%% @doc Tests for node_aggregate: execute/2 (command routing) and apply_event/2 (state transitions).
%%%
%%% Pure function tests — no external dependencies (no ReckonDB, no mesh).
-module(node_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include("node_lifecycle_status.hrl").

%% Copied from node_aggregate.erl for test-side record access.
-record(node_state, {
    mri, public_key, key_type, identity_metadata, registered, registered_at,
    capabilities, connections, endorsements_given, subscriptions, ucan_grants,
    connectors, status
}).

%% ===================================================================
%% Test generators
%% ===================================================================

execute_test_() ->
    [
        {"register_identity happy path",        fun register_identity_happy/0},
        {"register_identity already registered", fun register_identity_already_registered/0},
        {"update_identity happy path",           fun update_identity_happy/0},
        {"update_identity not registered",       fun update_identity_not_registered/0},
        {"announce_capability happy path",       fun announce_capability_happy/0},
        {"update_capability happy path",         fun update_capability_happy/0},
        {"retract_capability happy path",        fun retract_capability_happy/0},
        {"connect_node happy path",              fun connect_node_happy/0},
        {"connect_node self-connect rejected",   fun connect_self_rejected/0},
        {"disconnect_node happy path",           fun disconnect_node_happy/0},
        {"endorse_capability happy path",        fun endorse_capability_happy/0},
        {"revoke_endorsement happy path",        fun revoke_endorsement_happy/0},
        {"subscribe_topic happy path",           fun subscribe_topic_happy/0},
        {"unsubscribe_topic happy path",         fun unsubscribe_topic_happy/0},
        {"grant_ucan happy path",                fun grant_ucan_happy/0},
        {"revoke_ucan happy path",               fun revoke_ucan_happy/0},
        {"register_connector happy path",        fun register_connector_happy/0},
        {"revoke_connector happy path",          fun revoke_connector_happy/0},
        {"activate_connector happy path",        fun activate_connector_happy/0},
        {"suspend_connector happy path",         fun suspend_connector_happy/0},
        {"unknown command returns error",        fun unknown_command/0},
        {"payload without command_type returns error", fun missing_command_type/0}
    ].

apply_event_test_() ->
    [
        {"identity_registered sets mri, key, status",       fun apply_identity_registered/0},
        {"identity_updated merges metadata",                fun apply_identity_updated/0},
        {"capability_announced adds to capabilities map",   fun apply_capability_announced/0},
        {"capability_updated merges into existing",         fun apply_capability_updated/0},
        {"capability_updated ignores unknown MRI",          fun apply_capability_updated_unknown/0},
        {"capability_retracted removes from map",           fun apply_capability_retracted/0},
        {"node_connected adds to connections",              fun apply_node_connected/0},
        {"node_disconnected removes from connections",      fun apply_node_disconnected/0},
        {"capability_endorsed adds endorsement",            fun apply_capability_endorsed/0},
        {"endorsement_revoked removes endorsement",         fun apply_endorsement_revoked/0},
        {"topic_subscribed adds to subscriptions",          fun apply_topic_subscribed/0},
        {"topic_unsubscribed removes from subscriptions",   fun apply_topic_unsubscribed/0},
        {"ucan_granted adds to grants",                     fun apply_ucan_granted/0},
        {"ucan_revoked removes from grants",                fun apply_ucan_revoked/0},
        {"connector_registered sets REGISTERED|ACTIVE",     fun apply_connector_registered/0},
        {"connector_revoked clears ACTIVE sets REVOKED",    fun apply_connector_revoked/0},
        {"connector_suspended clears ACTIVE sets SUSPENDED", fun apply_connector_suspended/0},
        {"connector_activated clears SUSPENDED sets ACTIVE", fun apply_connector_activated/0},
        {"connector_revoked on unknown id is no-op",        fun apply_connector_revoked_unknown/0},
        {"unknown event leaves state unchanged",            fun apply_unknown_event/0},
        {"apply_event handles binary keys",                 fun apply_event_binary_keys/0}
    ].

roundtrip_test_() ->
    [
        {"register then update identity roundtrip", fun roundtrip_register_update_identity/0},
        {"announce then retract capability roundtrip", fun roundtrip_announce_retract_capability/0},
        {"connect then disconnect roundtrip",       fun roundtrip_connect_disconnect/0},
        {"connector register → suspend → activate lifecycle", fun roundtrip_connector_lifecycle/0}
    ].

%% ===================================================================
%% Helpers
%% ===================================================================

fresh() -> node_aggregate:initial_state().

registered_state() ->
    S0 = fresh(),
    Event = #{
        event_type => <<"identity_registered_v1">>,
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk_test_abc123">>,
        key_type => <<"ed25519">>,
        metadata => #{},
        registered_at => 1000
    },
    node_aggregate:apply_event(S0, Event).

%% ===================================================================
%% Execute tests
%% ===================================================================

register_identity_happy() ->
    Payload = #{
        command_type => register_identity,
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk_test_abc123">>,
        key_type => <<"ed25519">>,
        metadata => #{},
        registered_at => 1000
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"identity_registered_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"mri:agent:io.macula/node1">>, maps:get(mri, Event)).

register_identity_already_registered() ->
    Payload = #{
        command_type => register_identity,
        mri => <<"mri:agent:io.macula/node2">>,
        public_key => <<"pk2">>,
        key_type => <<"ed25519">>
    },
    ?assertEqual({error, already_registered}, node_aggregate:execute(registered_state(), Payload)).

update_identity_happy() ->
    Payload = #{
        command_type => update_identity,
        mri => <<"mri:agent:io.macula/node1">>,
        metadata => #{version => <<"2.0">>},
        updated_at => 2000
    },
    {ok, [Event]} = node_aggregate:execute(registered_state(), Payload),
    ?assertEqual(<<"identity_updated_v1">>, maps:get(event_type, Event)).

update_identity_not_registered() ->
    Payload = #{
        command_type => update_identity,
        mri => <<"mri:agent:io.macula/node1">>,
        metadata => #{}
    },
    ?assertEqual({error, not_registered}, node_aggregate:execute(fresh(), Payload)).

announce_capability_happy() ->
    Payload = #{
        command_type => announce_capability,
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"weather">>],
        description => <<"Weather service">>
    },
    {ok, [_Event]} = node_aggregate:execute(fresh(), Payload).

update_capability_happy() ->
    Payload = #{
        command_type => update_capability,
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"weather">>, <<"forecast">>],
        description => <<"Updated weather service">>
    },
    {ok, [_Event]} = node_aggregate:execute(fresh(), Payload).

retract_capability_happy() ->
    Payload = #{
        command_type => retract_capability,
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>
    },
    {ok, [_Event]} = node_aggregate:execute(fresh(), Payload).

connect_node_happy() ->
    Payload = #{
        command_type => connect_node,
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node2">>
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"node_connected_v1">>, maps:get(event_type, Event)).

connect_self_rejected() ->
    Payload = #{
        command_type => connect_node,
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node1">>
    },
    ?assertEqual({error, cannot_connect_self}, node_aggregate:execute(fresh(), Payload)).

disconnect_node_happy() ->
    Payload = #{
        command_type => disconnect_node,
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node2">>
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"node_disconnected_v1">>, maps:get(event_type, Event)).

endorse_capability_happy() ->
    Payload = #{
        command_type => endorse_capability,
        endorser_identity => <<"mri:agent:io.macula/node1">>,
        capability_mri => <<"mri:capability:io.macula/weather">>
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"capability_endorsed_v1">>, maps:get(event_type, Event)).

revoke_endorsement_happy() ->
    Payload = #{
        command_type => revoke_endorsement,
        endorser_identity => <<"mri:agent:io.macula/node1">>,
        capability_mri => <<"mri:capability:io.macula/weather">>
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"endorsement_revoked_v1">>, maps:get(event_type, Event)).

subscribe_topic_happy() ->
    Payload = #{
        command_type => subscribe_topic,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        topic => <<"events.weather">>,
        filter => undefined,
        subscribed_at => 1000
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"topic_subscribed_v1">>, maps:get(event_type, Event)).

unsubscribe_topic_happy() ->
    Payload = #{
        command_type => unsubscribe_topic,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        topic => <<"events.weather">>,
        unsubscribed_at => 2000
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"topic_unsubscribed_v1">>, maps:get(event_type, Event)).

grant_ucan_happy() ->
    Payload = #{
        command_type => grant_ucan,
        capability_id => <<"cap-001">>,
        issuer => <<"mri:agent:io.macula/node1">>,
        audience => <<"mri:agent:io.macula/node2">>,
        resource => <<"mri:capability:io.macula/weather">>,
        actions => [<<"read">>],
        expires_at => 99999,
        granted_at => 1000
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"ucan_granted_v1">>, maps:get(event_type, Event)).

revoke_ucan_happy() ->
    Payload = #{
        command_type => revoke_ucan,
        capability_id => <<"cap-001">>,
        revoker => <<"mri:agent:io.macula/node1">>,
        revoked_at => 2000
    },
    {ok, [Event]} = node_aggregate:execute(fresh(), Payload),
    ?assertEqual(<<"ucan_revoked_v1">>, maps:get(event_type, Event)).

register_connector_happy() ->
    Payload = #{
        command_type => register_connector,
        connector_id => <<"conn-001">>,
        name => <<"Test Connector">>
    },
    {ok, [_Event]} = node_aggregate:execute(fresh(), Payload).

revoke_connector_happy() ->
    Payload = #{
        command_type => revoke_connector,
        connector_id => <<"conn-001">>
    },
    {ok, [_Event]} = node_aggregate:execute(fresh(), Payload).

activate_connector_happy() ->
    Payload = #{
        command_type => activate_connector,
        connector_id => <<"conn-001">>
    },
    {ok, [_Event]} = node_aggregate:execute(fresh(), Payload).

suspend_connector_happy() ->
    Payload = #{
        command_type => suspend_connector,
        connector_id => <<"conn-001">>
    },
    {ok, [_Event]} = node_aggregate:execute(fresh(), Payload).

unknown_command() ->
    Payload = #{command_type => nonexistent_command},
    ?assertEqual({error, unknown_command}, node_aggregate:execute(fresh(), Payload)).

missing_command_type() ->
    ?assertEqual({error, unknown_command}, node_aggregate:execute(fresh(), #{foo => bar})).

%% ===================================================================
%% Apply event tests
%% ===================================================================

apply_identity_registered() ->
    Event = #{
        event_type => <<"identity_registered_v1">>,
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk_abc">>,
        key_type => <<"ed25519">>,
        metadata => #{role => <<"worker">>},
        registered_at => 1000
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    ?assertEqual(<<"mri:agent:io.macula/node1">>, S1#node_state.mri),
    ?assertEqual(<<"pk_abc">>, S1#node_state.public_key),
    ?assertEqual(<<"ed25519">>, S1#node_state.key_type),
    ?assertEqual(#{role => <<"worker">>}, S1#node_state.identity_metadata),
    ?assert(S1#node_state.registered),
    ?assertEqual(1000, S1#node_state.registered_at),
    ?assert((S1#node_state.status band ?NL_REGISTERED) =/= 0).

apply_identity_updated() ->
    S1 = registered_state(),
    Event = #{
        event_type => <<"identity_updated_v1">>,
        metadata => #{version => <<"2.0">>, extra => true}
    },
    S2 = node_aggregate:apply_event(S1, Event),
    ?assertEqual(#{version => <<"2.0">>, extra => true}, S2#node_state.identity_metadata),
    %% MRI unchanged
    ?assertEqual(<<"mri:agent:io.macula/node1">>, S2#node_state.mri).

apply_capability_announced() ->
    MRI = <<"mri:capability:io.macula/weather">>,
    Event = #{
        event_type => <<"capability_announced_v1">>,
        capability_mri => MRI,
        agent_identity => <<"mri:agent:io.macula/node1">>
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    ?assert(maps:is_key(MRI, S1#node_state.capabilities)),
    ?assertEqual(Event, maps:get(MRI, S1#node_state.capabilities)).

apply_capability_updated() ->
    MRI = <<"mri:capability:io.macula/weather">>,
    AnnEvent = #{
        event_type => <<"capability_announced_v1">>,
        capability_mri => MRI,
        description => <<"v1">>
    },
    UpdEvent = #{
        event_type => <<"capability_updated_v1">>,
        capability_mri => MRI,
        description => <<"v2">>
    },
    S1 = node_aggregate:apply_event(fresh(), AnnEvent),
    S2 = node_aggregate:apply_event(S1, UpdEvent),
    Cap = maps:get(MRI, S2#node_state.capabilities),
    ?assertEqual(<<"v2">>, maps:get(description, Cap)).

apply_capability_updated_unknown() ->
    MRI = <<"mri:capability:io.macula/nonexistent">>,
    UpdEvent = #{
        event_type => <<"capability_updated_v1">>,
        capability_mri => MRI,
        description => <<"v2">>
    },
    S0 = fresh(),
    S1 = node_aggregate:apply_event(S0, UpdEvent),
    ?assertEqual(#{}, S1#node_state.capabilities).

apply_capability_retracted() ->
    MRI = <<"mri:capability:io.macula/weather">>,
    AnnEvent = #{
        event_type => <<"capability_announced_v1">>,
        capability_mri => MRI
    },
    RetEvent = #{
        event_type => <<"capability_retracted_v1">>,
        capability_mri => MRI
    },
    S1 = node_aggregate:apply_event(fresh(), AnnEvent),
    S2 = node_aggregate:apply_event(S1, RetEvent),
    ?assertNot(maps:is_key(MRI, S2#node_state.capabilities)).

apply_node_connected() ->
    Target = <<"mri:agent:io.macula/node2">>,
    Event = #{
        event_type => <<"node_connected_v1">>,
        target_node => Target,
        connected_at => 1000
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    ?assert(maps:is_key(Target, S1#node_state.connections)).

apply_node_disconnected() ->
    Target = <<"mri:agent:io.macula/node2">>,
    ConnEvent = #{event_type => <<"node_connected_v1">>, target_node => Target},
    DiscEvent = #{event_type => <<"node_disconnected_v1">>, target_node => Target},
    S1 = node_aggregate:apply_event(fresh(), ConnEvent),
    S2 = node_aggregate:apply_event(S1, DiscEvent),
    ?assertNot(maps:is_key(Target, S2#node_state.connections)).

apply_capability_endorsed() ->
    Endorser = <<"mri:agent:io.macula/endorser1">>,
    MRI = <<"mri:capability:io.macula/weather">>,
    Event = #{
        event_type => <<"capability_endorsed_v1">>,
        endorser_identity => Endorser,
        capability_mri => MRI,
        endorsed_at => 1000
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    Key = <<Endorser/binary, ":", MRI/binary>>,
    ?assert(maps:is_key(Key, S1#node_state.endorsements_given)).

apply_endorsement_revoked() ->
    Endorser = <<"mri:agent:io.macula/endorser1">>,
    MRI = <<"mri:capability:io.macula/weather">>,
    EndEvent = #{
        event_type => <<"capability_endorsed_v1">>,
        endorser_identity => Endorser,
        capability_mri => MRI
    },
    RevEvent = #{
        event_type => <<"endorsement_revoked_v1">>,
        endorser_identity => Endorser,
        capability_mri => MRI
    },
    S1 = node_aggregate:apply_event(fresh(), EndEvent),
    S2 = node_aggregate:apply_event(S1, RevEvent),
    Key = <<Endorser/binary, ":", MRI/binary>>,
    ?assertNot(maps:is_key(Key, S2#node_state.endorsements_given)).

apply_topic_subscribed() ->
    Topic = <<"events.weather">>,
    Event = #{
        event_type => <<"topic_subscribed_v1">>,
        topic => Topic,
        agent_identity => <<"agent1">>
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    ?assert(maps:is_key(Topic, S1#node_state.subscriptions)).

apply_topic_unsubscribed() ->
    Topic = <<"events.weather">>,
    SubEvent = #{event_type => <<"topic_subscribed_v1">>, topic => Topic},
    UnsubEvent = #{event_type => <<"topic_unsubscribed_v1">>, topic => Topic},
    S1 = node_aggregate:apply_event(fresh(), SubEvent),
    S2 = node_aggregate:apply_event(S1, UnsubEvent),
    ?assertNot(maps:is_key(Topic, S2#node_state.subscriptions)).

apply_ucan_granted() ->
    CapId = <<"cap-001">>,
    Event = #{
        event_type => <<"ucan_granted_v1">>,
        capability_id => CapId,
        issuer => <<"agent1">>
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    ?assert(maps:is_key(CapId, S1#node_state.ucan_grants)).

apply_ucan_revoked() ->
    CapId = <<"cap-001">>,
    GrantEvent = #{event_type => <<"ucan_granted_v1">>, capability_id => CapId},
    RevokeEvent = #{event_type => <<"ucan_revoked_v1">>, capability_id => CapId},
    S1 = node_aggregate:apply_event(fresh(), GrantEvent),
    S2 = node_aggregate:apply_event(S1, RevokeEvent),
    ?assertNot(maps:is_key(CapId, S2#node_state.ucan_grants)).

apply_connector_registered() ->
    ConnId = <<"conn-001">>,
    Event = #{
        event_type => <<"connector_registered_v1">>,
        connector_id => ConnId,
        name => <<"Test">>
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    ?assert(maps:is_key(ConnId, S1#node_state.connectors)),
    Conn = maps:get(ConnId, S1#node_state.connectors),
    Status = maps:get(status, Conn),
    ?assert((Status band ?CONN_REGISTERED) =/= 0),
    ?assert((Status band ?CONN_ACTIVE) =/= 0).

apply_connector_revoked() ->
    ConnId = <<"conn-001">>,
    RegEvent = #{event_type => <<"connector_registered_v1">>, connector_id => ConnId},
    RevEvent = #{event_type => <<"connector_revoked_v1">>, connector_id => ConnId},
    S1 = node_aggregate:apply_event(fresh(), RegEvent),
    S2 = node_aggregate:apply_event(S1, RevEvent),
    Conn = maps:get(ConnId, S2#node_state.connectors),
    Status = maps:get(status, Conn),
    ?assert((Status band ?CONN_REVOKED) =/= 0),
    ?assertEqual(0, Status band ?CONN_ACTIVE).

apply_connector_suspended() ->
    ConnId = <<"conn-001">>,
    RegEvent = #{event_type => <<"connector_registered_v1">>, connector_id => ConnId},
    SusEvent = #{event_type => <<"connector_suspended_v1">>, connector_id => ConnId},
    S1 = node_aggregate:apply_event(fresh(), RegEvent),
    S2 = node_aggregate:apply_event(S1, SusEvent),
    Conn = maps:get(ConnId, S2#node_state.connectors),
    Status = maps:get(status, Conn),
    ?assert((Status band ?CONN_SUSPENDED) =/= 0),
    ?assertEqual(0, Status band ?CONN_ACTIVE).

apply_connector_activated() ->
    ConnId = <<"conn-001">>,
    RegEvent = #{event_type => <<"connector_registered_v1">>, connector_id => ConnId},
    SusEvent = #{event_type => <<"connector_suspended_v1">>, connector_id => ConnId},
    ActEvent = #{event_type => <<"connector_activated_v1">>, connector_id => ConnId},
    S1 = node_aggregate:apply_event(fresh(), RegEvent),
    S2 = node_aggregate:apply_event(S1, SusEvent),
    S3 = node_aggregate:apply_event(S2, ActEvent),
    Conn = maps:get(ConnId, S3#node_state.connectors),
    Status = maps:get(status, Conn),
    ?assert((Status band ?CONN_ACTIVE) =/= 0),
    ?assertEqual(0, Status band ?CONN_SUSPENDED).

apply_connector_revoked_unknown() ->
    RevEvent = #{event_type => <<"connector_revoked_v1">>, connector_id => <<"unknown">>},
    S0 = fresh(),
    S1 = node_aggregate:apply_event(S0, RevEvent),
    ?assertEqual(#{}, S1#node_state.connectors).

apply_unknown_event() ->
    S0 = fresh(),
    S1 = node_aggregate:apply_event(S0, #{event_type => <<"totally_unknown_v1">>}),
    ?assertEqual(S0, S1).

apply_event_binary_keys() ->
    Event = #{
        <<"event_type">> => <<"identity_registered_v1">>,
        <<"mri">> => <<"mri:agent:io.macula/binkey">>,
        <<"public_key">> => <<"pk_bin">>,
        <<"key_type">> => <<"ed25519">>,
        <<"metadata">> => #{},
        <<"registered_at">> => 2000
    },
    S1 = node_aggregate:apply_event(fresh(), Event),
    ?assertEqual(<<"mri:agent:io.macula/binkey">>, S1#node_state.mri),
    ?assert(S1#node_state.registered).

%% ===================================================================
%% Roundtrip tests: execute → apply_event → execute
%% ===================================================================

roundtrip_register_update_identity() ->
    S0 = fresh(),
    %% Register
    RegPayload = #{
        command_type => register_identity,
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk">>,
        key_type => <<"ed25519">>,
        metadata => #{},
        registered_at => 1000
    },
    {ok, [RegEvent]} = node_aggregate:execute(S0, RegPayload),
    S1 = node_aggregate:apply_event(S0, RegEvent),
    %% Now registered — update should work
    UpdPayload = #{
        command_type => update_identity,
        mri => <<"mri:agent:io.macula/node1">>,
        metadata => #{v => <<"2">>},
        updated_at => 2000
    },
    {ok, [UpdEvent]} = node_aggregate:execute(S1, UpdPayload),
    S2 = node_aggregate:apply_event(S1, UpdEvent),
    ?assertEqual(#{v => <<"2">>}, S2#node_state.identity_metadata),
    %% Register again should fail
    ?assertEqual({error, already_registered}, node_aggregate:execute(S2, RegPayload)).

roundtrip_announce_retract_capability() ->
    S0 = fresh(),
    MRI = <<"mri:capability:io.macula/weather">>,
    %% Announce
    AnnPayload = #{
        command_type => announce_capability,
        capability_mri => MRI,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"weather">>],
        description => <<"Weather">>
    },
    {ok, [AnnEvent]} = node_aggregate:execute(S0, AnnPayload),
    %% Capability events are opaque records — convert to map for apply_event
    AnnMap = capability_announced_v1:to_map(AnnEvent),
    S1 = node_aggregate:apply_event(S0, AnnMap),
    ?assert(maps:is_key(MRI, S1#node_state.capabilities)),
    %% Retract
    RetPayload = #{
        command_type => retract_capability,
        capability_mri => MRI,
        agent_identity => <<"mri:agent:io.macula/node1">>
    },
    {ok, [RetEvent]} = node_aggregate:execute(S1, RetPayload),
    RetMap = capability_retracted_v1:to_map(RetEvent),
    S2 = node_aggregate:apply_event(S1, RetMap),
    ?assertNot(maps:is_key(MRI, S2#node_state.capabilities)).

roundtrip_connect_disconnect() ->
    S0 = fresh(),
    Target = <<"mri:agent:io.macula/node2">>,
    %% Connect
    ConnPayload = #{
        command_type => connect_node,
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => Target
    },
    {ok, [ConnEvent]} = node_aggregate:execute(S0, ConnPayload),
    S1 = node_aggregate:apply_event(S0, ConnEvent),
    ?assert(maps:is_key(Target, S1#node_state.connections)),
    %% Disconnect
    DiscPayload = #{
        command_type => disconnect_node,
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => Target
    },
    {ok, [DiscEvent]} = node_aggregate:execute(S1, DiscPayload),
    S2 = node_aggregate:apply_event(S1, DiscEvent),
    ?assertNot(maps:is_key(Target, S2#node_state.connections)).

roundtrip_connector_lifecycle() ->
    S0 = fresh(),
    ConnId = <<"conn-001">>,
    %% Register
    RegPayload = #{
        command_type => register_connector,
        connector_id => ConnId,
        name => <<"My Connector">>
    },
    {ok, [RegEvent]} = node_aggregate:execute(S0, RegPayload),
    RegMap = connector_registered_v1:to_map(RegEvent),
    S1 = node_aggregate:apply_event(S0, RegMap),
    Conn1 = maps:get(ConnId, S1#node_state.connectors),
    ?assert((maps:get(status, Conn1) band ?CONN_ACTIVE) =/= 0),
    %% Suspend
    SusPayload = #{command_type => suspend_connector, connector_id => ConnId},
    {ok, [SusEvent]} = node_aggregate:execute(S1, SusPayload),
    SusMap = connector_suspended_v1:to_map(SusEvent),
    S2 = node_aggregate:apply_event(S1, SusMap),
    Conn2 = maps:get(ConnId, S2#node_state.connectors),
    ?assert((maps:get(status, Conn2) band ?CONN_SUSPENDED) =/= 0),
    ?assertEqual(0, maps:get(status, Conn2) band ?CONN_ACTIVE),
    %% Activate
    ActPayload = #{command_type => activate_connector, connector_id => ConnId},
    {ok, [ActEvent]} = node_aggregate:execute(S2, ActPayload),
    ActMap = connector_activated_v1:to_map(ActEvent),
    S3 = node_aggregate:apply_event(S2, ActMap),
    Conn3 = maps:get(ConnId, S3#node_state.connectors),
    ?assert((maps:get(status, Conn3) band ?CONN_ACTIVE) =/= 0),
    ?assertEqual(0, maps:get(status, Conn3) band ?CONN_SUSPENDED).
