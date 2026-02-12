%%% @doc Tests for node lifecycle handlers (maybe_* modules).
%%%
%%% Tests each handler's handle_from_map/1 in isolation — validation logic, error paths.
%%% Pure function tests — no external dependencies.
-module(node_handler_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

register_identity_test_() ->
    [
        {"valid identity",    fun reg_id_valid/0},
        {"empty MRI",         fun reg_id_empty_mri/0},
        {"empty public_key",  fun reg_id_empty_pk/0},
        {"bad key_type",      fun reg_id_bad_key_type/0},
        {"non-MRI format",    fun reg_id_non_mri/0}
    ].

update_identity_test_() ->
    [
        {"valid update",     fun upd_id_valid/0},
        {"empty MRI",        fun upd_id_empty_mri/0}
    ].

announce_capability_test_() ->
    [
        {"valid announcement",    fun ann_cap_valid/0},
        {"invalid MRI",           fun ann_cap_invalid_mri/0},
        {"invalid agent identity", fun ann_cap_invalid_agent/0},
        {"invalid tags",          fun ann_cap_invalid_tags/0}
    ].

connect_node_test_() ->
    [
        {"valid connection",   fun conn_valid/0},
        {"self-connect",       fun conn_self/0}
    ].

disconnect_node_test_() ->
    [
        {"valid disconnect",   fun disc_valid/0},
        {"self-disconnect",    fun disc_self/0}
    ].

subscribe_topic_test_() ->
    [
        {"valid subscription", fun sub_valid/0},
        {"empty agent",        fun sub_empty_agent/0},
        {"empty topic",        fun sub_empty_topic/0}
    ].

unsubscribe_topic_test_() ->
    [
        {"valid unsubscription", fun unsub_valid/0},
        {"empty agent",          fun unsub_empty_agent/0},
        {"empty topic",          fun unsub_empty_topic/0}
    ].

grant_ucan_test_() ->
    [
        {"valid grant",          fun ucan_valid/0},
        {"empty capability_id",  fun ucan_empty_cap_id/0},
        {"empty issuer",         fun ucan_empty_issuer/0},
        {"invalid issuer MRI",   fun ucan_invalid_issuer/0},
        {"invalid audience MRI", fun ucan_invalid_audience/0},
        {"invalid resource URI", fun ucan_invalid_resource/0},
        {"empty actions",        fun ucan_empty_actions/0},
        {"unknown actions",      fun ucan_unknown_actions/0},
        {"invalid expiration",   fun ucan_invalid_expiration/0}
    ].

revoke_ucan_test_() ->
    [
        {"valid revocation",     fun revoke_ucan_valid/0},
        {"empty capability_id",  fun revoke_ucan_empty_cap/0},
        {"empty revoker",        fun revoke_ucan_empty_revoker/0}
    ].

register_connector_test_() ->
    [
        {"valid registration",   fun reg_conn_valid/0},
        {"empty connector_id",   fun reg_conn_empty_id/0},
        {"empty name",           fun reg_conn_empty_name/0}
    ].

capability_validation_test_() ->
    [
        {"validate_mri valid capability", fun val_mri_cap/0},
        {"validate_mri valid proc",       fun val_mri_proc/0},
        {"validate_mri invalid type",     fun val_mri_bad_type/0},
        {"validate_mri non-mri",          fun val_mri_non_mri/0},
        {"validate_mri not binary",       fun val_mri_not_binary/0},
        {"validate_agent_identity valid agent MRI", fun val_agent_mri/0},
        {"validate_agent_identity valid DID",       fun val_agent_did/0},
        {"validate_agent_identity invalid",         fun val_agent_invalid/0},
        {"validate_agent_identity empty",           fun val_agent_empty/0},
        {"validate_tags valid list",      fun val_tags_valid/0},
        {"validate_tags empty tag",       fun val_tags_empty_entry/0},
        {"validate_tags not a list",      fun val_tags_not_list/0},
        {"is_owner same",                 fun val_owner_same/0},
        {"is_owner different",            fun val_owner_different/0}
    ].

%% ===================================================================
%% register_identity tests
%% ===================================================================

reg_id_valid() ->
    Payload = #{
        mri => <<"mri:agent:io.macula/node1">>,
        public_key => <<"pk_test_abc123">>,
        key_type => <<"ed25519">>,
        metadata => #{},
        registered_at => 1000
    },
    {ok, [Event]} = maybe_register_identity:handle_from_map(Payload),
    ?assertEqual(<<"identity_registered_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"mri:agent:io.macula/node1">>, maps:get(mri, Event)).

reg_id_empty_mri() ->
    Payload = #{mri => <<>>, public_key => <<"pk">>, key_type => <<"ed25519">>},
    ?assertEqual({error, mri_required}, maybe_register_identity:handle_from_map(Payload)).

reg_id_empty_pk() ->
    Payload = #{mri => <<"mri:agent:io.macula/x">>, public_key => <<>>, key_type => <<"ed25519">>},
    ?assertEqual({error, public_key_required}, maybe_register_identity:handle_from_map(Payload)).

reg_id_bad_key_type() ->
    Payload = #{mri => <<"mri:agent:io.macula/x">>, public_key => <<"pk">>, key_type => <<"rsa">>},
    ?assertEqual({error, invalid_key_type}, maybe_register_identity:handle_from_map(Payload)).

reg_id_non_mri() ->
    Payload = #{mri => <<"not-an-mri">>, public_key => <<"pk">>, key_type => <<"ed25519">>},
    ?assertEqual({error, invalid_mri_format}, maybe_register_identity:handle_from_map(Payload)).

%% ===================================================================
%% update_identity tests
%% ===================================================================

upd_id_valid() ->
    Payload = #{
        mri => <<"mri:agent:io.macula/node1">>,
        metadata => #{version => <<"2.0">>},
        updated_at => 2000
    },
    {ok, [Event]} = maybe_update_identity:handle_from_map(Payload),
    ?assertEqual(<<"identity_updated_v1">>, maps:get(event_type, Event)).

upd_id_empty_mri() ->
    Payload = #{mri => <<>>, metadata => #{}},
    ?assertEqual({error, mri_required}, maybe_update_identity:handle_from_map(Payload)).

%% ===================================================================
%% announce_capability tests
%% ===================================================================

ann_cap_valid() ->
    Payload = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"weather">>],
        description => <<"Weather service">>
    },
    {ok, [_Event]} = maybe_announce_capability:handle_from_map(Payload).

ann_cap_invalid_mri() ->
    Payload = #{
        capability_mri => <<"not-an-mri">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<"x">>],
        description => <<"test">>
    },
    ?assertEqual({error, invalid_mri}, maybe_announce_capability:handle_from_map(Payload)).

ann_cap_invalid_agent() ->
    Payload = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"invalid-agent">>,
        tags => [<<"x">>],
        description => <<"test">>
    },
    ?assertEqual({error, invalid_agent_identity}, maybe_announce_capability:handle_from_map(Payload)).

ann_cap_invalid_tags() ->
    Payload = #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"mri:agent:io.macula/node1">>,
        tags => [<<>>],
        description => <<"test">>
    },
    ?assertEqual({error, invalid_tags}, maybe_announce_capability:handle_from_map(Payload)).

%% ===================================================================
%% connect_node tests
%% ===================================================================

conn_valid() ->
    Payload = #{
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node2">>
    },
    {ok, [Event]} = maybe_connect_node:handle_from_map(Payload),
    ?assertEqual(<<"node_connected_v1">>, maps:get(event_type, Event)).

conn_self() ->
    Payload = #{
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node1">>
    },
    ?assertEqual({error, cannot_connect_self}, maybe_connect_node:handle_from_map(Payload)).

%% ===================================================================
%% disconnect_node tests
%% ===================================================================

disc_valid() ->
    Payload = #{
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node2">>
    },
    {ok, [Event]} = maybe_disconnect_node:handle_from_map(Payload),
    ?assertEqual(<<"node_disconnected_v1">>, maps:get(event_type, Event)).

disc_self() ->
    Payload = #{
        source_node => <<"mri:agent:io.macula/node1">>,
        target_node => <<"mri:agent:io.macula/node1">>
    },
    ?assertEqual({error, cannot_disconnect_self}, maybe_disconnect_node:handle_from_map(Payload)).

%% ===================================================================
%% subscribe_topic tests
%% ===================================================================

sub_valid() ->
    Payload = #{
        agent_identity => <<"mri:agent:io.macula/node1">>,
        topic => <<"events.weather">>,
        filter => undefined,
        subscribed_at => 1000
    },
    {ok, [Event]} = maybe_subscribe_topic:handle_from_map(Payload),
    ?assertEqual(<<"topic_subscribed_v1">>, maps:get(event_type, Event)).

sub_empty_agent() ->
    Payload = #{agent_identity => <<>>, topic => <<"events.weather">>},
    ?assertEqual({error, agent_identity_required}, maybe_subscribe_topic:handle_from_map(Payload)).

sub_empty_topic() ->
    Payload = #{agent_identity => <<"mri:agent:io.macula/node1">>, topic => <<>>},
    ?assertEqual({error, topic_required}, maybe_subscribe_topic:handle_from_map(Payload)).

%% ===================================================================
%% unsubscribe_topic tests
%% ===================================================================

unsub_valid() ->
    Payload = #{
        agent_identity => <<"mri:agent:io.macula/node1">>,
        topic => <<"events.weather">>,
        unsubscribed_at => 2000
    },
    {ok, [Event]} = maybe_unsubscribe_topic:handle_from_map(Payload),
    ?assertEqual(<<"topic_unsubscribed_v1">>, maps:get(event_type, Event)).

unsub_empty_agent() ->
    Payload = #{agent_identity => <<>>, topic => <<"events.weather">>},
    ?assertEqual({error, agent_identity_required}, maybe_unsubscribe_topic:handle_from_map(Payload)).

unsub_empty_topic() ->
    Payload = #{agent_identity => <<"mri:agent:io.macula/node1">>, topic => <<>>},
    ?assertEqual({error, topic_required}, maybe_unsubscribe_topic:handle_from_map(Payload)).

%% ===================================================================
%% grant_ucan tests
%% ===================================================================

ucan_valid() ->
    Payload = #{
        capability_id => <<"cap-001">>,
        issuer => <<"mri:agent:io.macula/node1">>,
        audience => <<"mri:agent:io.macula/node2">>,
        resource => <<"mri:capability:io.macula/weather">>,
        actions => [<<"read">>, <<"write">>],
        expires_at => 99999,
        granted_at => 1000
    },
    {ok, [Event]} = maybe_grant_ucan:handle_from_map(Payload),
    ?assertEqual(<<"ucan_granted_v1">>, maps:get(event_type, Event)).

ucan_empty_cap_id() ->
    Payload = ucan_base_payload(#{capability_id => <<>>}),
    ?assertEqual({error, capability_id_required}, maybe_grant_ucan:handle_from_map(Payload)).

ucan_empty_issuer() ->
    Payload = ucan_base_payload(#{issuer => <<>>}),
    ?assertEqual({error, issuer_required}, maybe_grant_ucan:handle_from_map(Payload)).

ucan_invalid_issuer() ->
    Payload = ucan_base_payload(#{issuer => <<"not-a-valid-mri">>}),
    ?assertEqual({error, invalid_issuer_mri}, maybe_grant_ucan:handle_from_map(Payload)).

ucan_invalid_audience() ->
    Payload = ucan_base_payload(#{audience => <<"not-valid">>}),
    ?assertEqual({error, invalid_audience_mri}, maybe_grant_ucan:handle_from_map(Payload)).

ucan_invalid_resource() ->
    Payload = ucan_base_payload(#{resource => <<"not-a-uri">>}),
    ?assertEqual({error, invalid_resource_uri}, maybe_grant_ucan:handle_from_map(Payload)).

ucan_empty_actions() ->
    Payload = ucan_base_payload(#{actions => []}),
    ?assertEqual({error, actions_required}, maybe_grant_ucan:handle_from_map(Payload)).

ucan_unknown_actions() ->
    Payload = ucan_base_payload(#{actions => [<<"read">>, <<"destroy">>]}),
    {error, {unknown_actions, [<<"destroy">>]}} = maybe_grant_ucan:handle_from_map(Payload).

ucan_invalid_expiration() ->
    %% expires_at must be > granted_at
    Payload = ucan_base_payload(#{expires_at => 500, granted_at => 1000}),
    ?assertEqual({error, invalid_expiration}, maybe_grant_ucan:handle_from_map(Payload)).

ucan_base_payload(Overrides) ->
    Base = #{
        capability_id => <<"cap-001">>,
        issuer => <<"mri:agent:io.macula/node1">>,
        audience => <<"mri:agent:io.macula/node2">>,
        resource => <<"mri:capability:io.macula/weather">>,
        actions => [<<"read">>],
        expires_at => 99999,
        granted_at => 1000
    },
    maps:merge(Base, Overrides).

%% ===================================================================
%% revoke_ucan tests
%% ===================================================================

revoke_ucan_valid() ->
    Payload = #{
        capability_id => <<"cap-001">>,
        revoker => <<"mri:agent:io.macula/node1">>,
        revoked_at => 2000
    },
    {ok, [Event]} = maybe_revoke_ucan:handle_from_map(Payload),
    ?assertEqual(<<"ucan_revoked_v1">>, maps:get(event_type, Event)).

revoke_ucan_empty_cap() ->
    Payload = #{capability_id => <<>>, revoker => <<"agent1">>},
    ?assertEqual({error, capability_id_required}, maybe_revoke_ucan:handle_from_map(Payload)).

revoke_ucan_empty_revoker() ->
    Payload = #{capability_id => <<"cap-001">>, revoker => <<>>},
    ?assertEqual({error, revoker_required}, maybe_revoke_ucan:handle_from_map(Payload)).

%% ===================================================================
%% register_connector tests
%% ===================================================================

reg_conn_valid() ->
    Payload = #{connector_id => <<"conn-001">>, name => <<"My Connector">>},
    {ok, [_Event]} = maybe_register_connector:handle_from_map(Payload).

reg_conn_empty_id() ->
    Payload = #{connector_id => <<>>, name => <<"test">>},
    ?assertEqual({error, empty_connector_id}, maybe_register_connector:handle_from_map(Payload)).

reg_conn_empty_name() ->
    Payload = #{connector_id => <<"conn-001">>, name => <<>>},
    ?assertEqual({error, empty_name}, maybe_register_connector:handle_from_map(Payload)).

%% ===================================================================
%% capability_validation tests
%% ===================================================================

val_mri_cap() ->
    ?assertEqual(ok, capability_validation:validate_mri(<<"mri:capability:io.macula/weather">>)).

val_mri_proc() ->
    ?assertEqual(ok, capability_validation:validate_mri(<<"mri:proc:io.macula/add">>)).

val_mri_bad_type() ->
    ?assertEqual({error, invalid_mri_type}, capability_validation:validate_mri(<<"mri:agent:io.macula/x">>)).

val_mri_non_mri() ->
    ?assertEqual({error, invalid_mri}, capability_validation:validate_mri(<<"not-an-mri">>)).

val_mri_not_binary() ->
    ?assertEqual({error, invalid_mri}, capability_validation:validate_mri(123)).

val_agent_mri() ->
    ?assertEqual(ok, capability_validation:validate_agent_identity(<<"mri:agent:io.macula/node1">>)).

val_agent_did() ->
    ?assertEqual(ok, capability_validation:validate_agent_identity(<<"did:key:z6Mk...">>)).

val_agent_invalid() ->
    ?assertEqual({error, invalid_agent_identity}, capability_validation:validate_agent_identity(<<"bad-id">>)).

val_agent_empty() ->
    ?assertEqual({error, invalid_agent_identity}, capability_validation:validate_agent_identity(<<>>)).

val_tags_valid() ->
    ?assertEqual(ok, capability_validation:validate_tags([<<"weather">>, <<"forecast">>])).

val_tags_empty_entry() ->
    ?assertEqual({error, invalid_tags}, capability_validation:validate_tags([<<"ok">>, <<>>])).

val_tags_not_list() ->
    ?assertEqual({error, invalid_tags}, capability_validation:validate_tags(<<"not-a-list">>)).

val_owner_same() ->
    ?assert(capability_validation:is_owner(<<"agent1">>, <<"agent1">>)).

val_owner_different() ->
    ?assertNot(capability_validation:is_owner(<<"agent1">>, <<"agent2">>)).
