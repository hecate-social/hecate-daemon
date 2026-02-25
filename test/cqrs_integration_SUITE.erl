%%% @doc Integration tests for complete CQRS flow
%%% Tests: Command → Event → ReckonDB → Projection → Query
%%%
%%% Updated for consolidated node lifecycle apps:
%%% - guide_node_lifecycle (CMD)
%%% - query_node_lifecycle (QRY)
-module(cqrs_integration_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, groups/0, init_per_suite/1, end_per_suite/1]).
-export([init_per_group/2, end_per_group/2]).
-export([init_per_testcase/2, end_per_testcase/2]).
-export([
    test_capability_announce_flow/1,
    test_capability_update_flow/1,
    test_capability_retract_flow/1,
    test_subscription_flow/1,
    test_identity_flow/1,
    test_ucan_flow/1,
    test_connection_flow/1
]).

%%--------------------------------------------------------------------
%% CT Callbacks
%%--------------------------------------------------------------------

all() ->
    [
        {group, cqrs_flows}
    ].

groups() ->
    [
        {cqrs_flows, [sequence], [
            test_capability_announce_flow,
            test_capability_update_flow,
            test_capability_retract_flow,
            test_subscription_flow,
            test_identity_flow,
            test_ucan_flow,
            test_connection_flow
        ]}
    ].

init_per_suite(Config) ->
    ct:pal("Initializing CQRS integration test suite..."),

    %% Add umbrella app ebin directories to code path
    {file, SuiteBeam} = code:is_loaded(?MODULE),
    SuiteDir = filename:dirname(SuiteBeam),
    LibDir = filename:dirname(filename:dirname(SuiteDir)),
    ct:pal("Found lib dir: ~s", [LibDir]),

    %% Ensure data directories exist
    DataDir = "/tmp/hecate_test_" ++ integer_to_list(erlang:system_time(millisecond)),
    ok = filelib:ensure_dir(DataDir ++ "/"),

    %% Set application environment for test data directory
    application:set_env(hecate, data_dir, DataDir),

    %% Start required applications
    {ok, _} = application:ensure_all_started(crypto),
    {ok, _} = application:ensure_all_started(esqlite),

    ct:pal("Test suite initialized"),

    [{data_dir, DataDir} | Config].

init_per_group(cqrs_flows, Config) ->
    ct:pal("Initializing CQRS flows group..."),
    Config;

init_per_group(_Group, Config) ->
    Config.

end_per_group(cqrs_flows, _Config) ->
    ct:pal("Cleaning up CQRS flows group..."),
    ok;

end_per_group(_Group, _Config) ->
    ok.

end_per_suite(Config) ->
    ct:pal("Cleaning up test suite..."),

    DataDir = proplists:get_value(data_dir, Config),
    os:cmd("rm -rf " ++ DataDir),

    ct:pal("Test suite cleaned up"),
    ok.

init_per_testcase(TestCase, Config) ->
    ct:pal("~n========== Starting test: ~p ==========~n", [TestCase]),
    Config.

end_per_testcase(TestCase, _Config) ->
    ct:pal("~n========== Finished test: ~p ==========~n", [TestCase]),
    ok.

%%--------------------------------------------------------------------
%% Test Cases
%%--------------------------------------------------------------------

test_capability_announce_flow(_Config) ->
    ct:pal("Testing capability announcement flow..."),

    MRI = <<"mri:capability:io.macula/test-weather-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    AgentID = <<"mri:agent:io.macula/test-agent">>,

    {ok, Cmd} = announce_capability_v1:new(#{
        capability_mri => MRI,
        agent_identity => AgentID,
        tags => [<<"weather">>, <<"test">>],
        description => <<"Test weather capability">>,
        metadata => #{announced_at => erlang:system_time(millisecond)}
    }),

    ct:pal("Handling announce_capability command..."),
    {ok, Events} = maybe_announce_capability:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [Event] = Events,

    EventMap = capability_announced_v1:to_map(Event),
    ?assertEqual(<<"capability_announced_v1">>, maps:get(event_type, EventMap)),
    ?assertEqual(MRI, maps:get(capability_mri, EventMap)),

    ct:pal("Command handled, event produced"),

    ct:pal("Projecting event to read model..."),
    ok = capability_announced_v1_to_capabilities:project(EventMap),

    ct:pal("Event projected to read model"),

    ct:pal("Querying read model..."),
    {ok, Capability} = get_capability_by_mri:execute(MRI),

    ?assertEqual(MRI, maps:get(mri, Capability)),
    ?assertEqual(AgentID, maps:get(agent_id, Capability)),

    ct:pal("Complete CQRS announce flow verified!"),
    ok.

test_capability_update_flow(_Config) ->
    ct:pal("Testing capability update flow..."),

    MRI = <<"mri:capability:io.macula/update-test-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    AgentID = <<"mri:agent:io.macula/test-agent">>,

    {ok, AnnounceCmd} = announce_capability_v1:new(#{
        capability_mri => MRI,
        agent_identity => AgentID,
        tags => [<<"original">>],
        description => <<"Original description">>,
        metadata => #{announced_at => erlang:system_time(millisecond)}
    }),

    {ok, [AnnounceEvent]} = maybe_announce_capability:handle(AnnounceCmd),
    ok = capability_announced_v1_to_capabilities:project(capability_announced_v1:to_map(AnnounceEvent)),

    {ok, UpdateCmd} = update_capability_v1:new(#{
        capability_mri => MRI,
        agent_identity => AgentID,
        tags => [<<"updated">>, <<"modified">>],
        description => <<"Updated description">>
    }),

    ct:pal("Handling update_capability command..."),
    {ok, Events} = maybe_update_capability:handle(UpdateCmd),

    ?assertEqual(1, length(Events)),
    [Event] = Events,

    EventMap = capability_updated_v1:to_map(Event),
    ?assertEqual(<<"capability_updated_v1">>, maps:get(event_type, EventMap)),

    ct:pal("Projecting update event..."),
    ok = capability_updated_v1_to_capabilities:project(EventMap),

    ct:pal("Verifying update in read model..."),
    {ok, Capability} = get_capability_by_mri:execute(MRI),

    ?assertEqual(<<"Updated description">>, maps:get(description, Capability)),

    ct:pal("Complete CQRS update flow verified!"),
    ok.

test_capability_retract_flow(_Config) ->
    ct:pal("Testing capability retract flow..."),

    MRI = <<"mri:capability:io.macula/retract-test-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    AgentID = <<"mri:agent:io.macula/test-agent">>,

    {ok, AnnounceCmd} = announce_capability_v1:new(#{
        capability_mri => MRI,
        agent_identity => AgentID,
        tags => [<<"to-be-retracted">>],
        description => <<"Will be retracted">>,
        metadata => #{announced_at => erlang:system_time(millisecond)}
    }),

    {ok, [AnnounceEvent]} = maybe_announce_capability:handle(AnnounceCmd),
    ok = capability_announced_v1_to_capabilities:project(capability_announced_v1:to_map(AnnounceEvent)),

    {ok, _} = get_capability_by_mri:execute(MRI),

    {ok, RetractCmd} = retract_capability_v1:new(MRI, AgentID, <<"No longer needed">>),

    ct:pal("Handling retract_capability command..."),
    {ok, Events} = maybe_retract_capability:handle(RetractCmd),

    ?assertEqual(1, length(Events)),
    [Event] = Events,

    EventMap = capability_retracted_v1:to_map(Event),
    ?assertEqual(<<"capability_retracted_v1">>, maps:get(event_type, EventMap)),

    ct:pal("Projecting retract event..."),
    ok = capability_retracted_v1_to_capabilities:project(EventMap),

    ct:pal("Verifying retraction..."),
    {ok, AllCapabilities} = get_capabilities_page:execute(),

    RetractedFound = lists:any(
        fun(#{mri := M}) -> M =:= MRI end,
        AllCapabilities
    ),

    ?assertNot(RetractedFound),

    ct:pal("Complete CQRS retract flow verified!"),
    ok.

test_subscription_flow(_Config) ->
    ct:pal("Testing subscription flow..."),

    Agent = <<"mri:agent:io.macula/subscriber-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Topic = <<"hecate.test.topic">>,

    Cmd = subscribe_topic_v1:new(Agent, Topic, undefined, erlang:system_time(millisecond)),

    ct:pal("Handling subscribe_topic command..."),
    {ok, Events} = maybe_subscribe_topic:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    ?assertEqual(<<"topic_subscribed_v1">>, maps:get(event_type, EventMap)),

    ct:pal("Projecting subscription event..."),
    ok = topic_subscribed_v1_to_subscriptions:project(EventMap),

    ct:pal("Querying subscriptions..."),
    {ok, Subscriptions} = get_subscriptions_page:execute(),

    ?assert(length(Subscriptions) > 0),

    TopicFound = lists:any(
        fun(#{topic := T}) -> T =:= Topic end,
        Subscriptions
    ),

    ?assert(TopicFound),

    ct:pal("Complete CQRS subscription flow verified!"),
    ok.

test_identity_flow(_Config) ->
    ct:pal("Testing identity registration flow..."),

    MRI = <<"mri:agent:io.macula/test-identity-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    PublicKey = <<"base64encodedkey123">>,

    Cmd = register_identity_v1:new(
        MRI,
        PublicKey,
        <<"ed25519">>,
        #{},
        erlang:system_time(millisecond)
    ),

    ct:pal("Handling register_identity command..."),
    {ok, Events} = maybe_register_identity:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    ?assertEqual(<<"identity_registered_v1">>, maps:get(event_type, EventMap)),

    ct:pal("Projecting identity event..."),
    ok = identity_registered_v1_to_identities:project(EventMap),

    ct:pal("Querying identity..."),
    {ok, Identity} = find_identity:execute(MRI),

    ?assertEqual(MRI, maps:get(mri, Identity)),
    ?assertEqual(PublicKey, maps:get(public_key, Identity)),
    ?assertEqual(<<"ed25519">>, maps:get(key_type, Identity)),

    ct:pal("Complete CQRS identity flow verified!"),
    ok.

test_ucan_flow(_Config) ->
    ct:pal("Testing UCAN grant flow..."),

    CapID = <<"cap-test-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Issuer = <<"mri:agent:io.macula/issuer">>,
    Audience = <<"mri:agent:io.macula/recipient-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Now = erlang:system_time(millisecond),
    ExpiresAt = Now + 86400000,

    Cmd = grant_ucan_v1:new(
        CapID,
        Issuer,
        Audience,
        <<"mri:resource:io.macula/test-resource">>,
        [<<"read">>, <<"write">>],
        ExpiresAt,
        Now
    ),

    ct:pal("Handling grant_ucan command..."),
    {ok, Events} = maybe_grant_ucan:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    ?assertEqual(<<"ucan_granted_v1">>, maps:get(event_type, EventMap)),

    ct:pal("Projecting UCAN grant..."),
    ok = ucan_granted_v1_to_ucan_grants:project(EventMap),

    ct:pal("Verifying UCAN grant..."),
    {ok, VerifyResult} = verify_ucan:execute(CapID),

    ?assertEqual(true, maps:get(valid, VerifyResult)),

    ct:pal("Complete CQRS UCAN flow verified!"),
    ok.

test_connection_flow(_Config) ->
    ct:pal("Testing mesh connection flow..."),

    Source = <<"mri:agent:io.macula/connector-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Target = <<"mri:agent:io.macula/target-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,

    Cmd = connect_node_v1:new(Source, Target, erlang:system_time(millisecond)),

    ct:pal("Handling connect_node command..."),
    {ok, Events} = maybe_connect_node:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    ?assertEqual(<<"node_connected_v1">>, maps:get(event_type, EventMap)),

    ct:pal("Projecting connection event..."),
    ok = node_connected_v1_to_connections:project(EventMap),

    ct:pal("Querying connections..."),
    {ok, Connections} = get_connections_page:execute(),

    ?assert(length(Connections) > 0),

    ct:pal("Complete CQRS connection flow verified!"),
    ok.
