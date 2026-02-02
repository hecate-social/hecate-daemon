%%% @doc Integration tests for complete CQRS flow
%%% Tests: Command → Event → ReckonDB → Projection → Query
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
    test_social_follow_flow/1
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
            test_social_follow_flow
        ]}
    ].

init_per_suite(Config) ->
    ct:pal("Initializing CQRS integration test suite..."),

    %% Add umbrella app ebin directories to code path
    %% CT doesn't automatically include umbrella apps in the code path
    %% We find the lib dir by using the test suite's beam file location
    {file, SuiteBeam} = code:is_loaded(?MODULE),
    SuiteDir = filename:dirname(SuiteBeam),
    %% SuiteDir is: _build/test/lib/hecate/test
    %% We want: _build/test/lib
    LibDir = filename:dirname(filename:dirname(SuiteDir)),
    ct:pal("Found lib dir: ~s", [LibDir]),

    Apps = [
        %% Query services
        query_capabilities,
        query_subscriptions,
        query_identities,
        query_ucan,
        query_social,
        %% Command services
        manage_capabilities,
        manage_subscriptions,
        manage_identities,
        manage_ucan,
        manage_social
    ],
    lists:foreach(fun(App) ->
        EbinDir = filename:join([LibDir, atom_to_list(App), "ebin"]),
        ct:pal("Adding to code path: ~s", [EbinDir]),
        case code:add_patha(EbinDir) of
            true -> ok;
            {error, Reason} ->
                ct:pal("WARNING: Failed to add ~s: ~p", [EbinDir, Reason])
        end
    end, Apps),

    %% Ensure data directories exist
    DataDir = "/tmp/hecate_test_" ++ integer_to_list(erlang:system_time(millisecond)),
    ok = filelib:ensure_dir(DataDir ++ "/"),

    %% Set application environment for test data directory
    application:set_env(query_capabilities, data_dir, DataDir),
    application:set_env(query_subscriptions, data_dir, DataDir),
    application:set_env(query_identities, data_dir, DataDir),
    application:set_env(query_ucan, data_dir, DataDir),
    application:set_env(query_social, data_dir, DataDir),
    application:set_env(hecate, data_dir, DataDir),

    %% Start required applications
    {ok, _} = application:ensure_all_started(crypto),
    {ok, _} = application:ensure_all_started(esqlite),

    ct:pal("✅ Test suite initialized"),

    [{data_dir, DataDir} | Config].

init_per_group(cqrs_flows, Config) ->
    ct:pal("Initializing CQRS flows group..."),

    %% Start SQLite stores manually for testing
    %% Using start (not start_link) to prevent stores from dying
    %% when the init_per_group process terminates
    {ok, _} = gen_server:start({local, query_capabilities_store}, query_capabilities_store, [], []),
    ok = query_capabilities_store:init_schema(),

    {ok, _} = gen_server:start({local, query_subscriptions_store}, query_subscriptions_store, [], []),
    ok = query_subscriptions_store:init_schema(),

    {ok, _} = gen_server:start({local, query_identities_store}, query_identities_store, [], []),
    ok = query_identities_store:init_schema(),

    {ok, _} = gen_server:start({local, query_ucan_store}, query_ucan_store, [], []),
    ok = query_ucan_store:init_schema(),

    {ok, _} = gen_server:start({local, query_social_store}, query_social_store, [], []),
    ok = query_social_store:init_schema(),

    ct:pal("✅ Stores started for group"),
    Config;

init_per_group(_Group, Config) ->
    Config.

end_per_group(cqrs_flows, _Config) ->
    ct:pal("Cleaning up CQRS flows group..."),

    %% Stop stores
    catch gen_server:stop(query_capabilities_store),
    catch gen_server:stop(query_subscriptions_store),
    catch gen_server:stop(query_identities_store),
    catch gen_server:stop(query_ucan_store),
    catch gen_server:stop(query_social_store),

    ct:pal("✅ Stores stopped"),
    ok;

end_per_group(_Group, _Config) ->
    ok.

end_per_suite(Config) ->
    ct:pal("Cleaning up test suite..."),

    %% Clean up test data directory
    DataDir = proplists:get_value(data_dir, Config),
    os:cmd("rm -rf " ++ DataDir),

    ct:pal("✅ Test suite cleaned up"),
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

    %% 1. Create command
    MRI = <<"mri:capability:io.macula/test-weather-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    AgentID = <<"mri:agent:io.macula/test-agent">>,

    {ok, Cmd} = announce_capability_v1:new(#{
        capability_mri => MRI,
        agent_identity => AgentID,
        tags => [<<"weather">>, <<"test">>],
        description => <<"Test weather capability">>,
        metadata => #{announced_at => erlang:system_time(millisecond)}
    }),

    %% 2. Handle command (produces events)
    ct:pal("Handling announce_capability command..."),
    {ok, Events} = maybe_announce_capability:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [Event] = Events,

    %% Convert to map for projection
    EventMap = capability_announced_v1:to_map(Event),
    ?assertEqual(<<"capability_announced_v1">>, maps:get(event_type, EventMap)),
    ?assertEqual(MRI, maps:get(capability_mri, EventMap)),

    ct:pal("✅ Command handled, event produced"),

    %% 3. Project event to read model
    ct:pal("Projecting event to read model..."),
    ok = capability_announced_v1_to_capabilities:project(EventMap),

    ct:pal("✅ Event projected to read model"),

    %% 4. Query read model
    ct:pal("Querying read model..."),
    {ok, Capability} = find_capability:execute(MRI),

    ?assertEqual(MRI, maps:get(mri, Capability)),
    ?assertEqual(AgentID, maps:get(agent_id, Capability)),

    ct:pal("✅ Capability found in read model"),
    ct:pal("🎉 Complete CQRS announce flow verified!"),

    ok.

test_capability_update_flow(_Config) ->
    ct:pal("Testing capability update flow..."),

    %% First announce a capability
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

    %% 1. Create update command
    {ok, UpdateCmd} = update_capability_v1:new(#{
        capability_mri => MRI,
        agent_identity => AgentID,
        tags => [<<"updated">>, <<"modified">>],
        description => <<"Updated description">>
    }),

    %% 2. Handle update command
    ct:pal("Handling update_capability command..."),
    {ok, Events} = maybe_update_capability:handle(UpdateCmd),

    ?assertEqual(1, length(Events)),
    [Event] = Events,

    EventMap = capability_updated_v1:to_map(Event),
    ?assertEqual(<<"capability_updated_v1">>, maps:get(event_type, EventMap)),

    ct:pal("✅ Update command handled"),

    %% 3. Project update event
    ct:pal("Projecting update event..."),
    ok = capability_updated_v1_to_capabilities:project(EventMap),

    ct:pal("✅ Update projected"),

    %% 4. Query and verify update
    ct:pal("Verifying update in read model..."),
    {ok, Capability} = find_capability:execute(MRI),

    ?assertEqual(<<"Updated description">>, maps:get(description, Capability)),

    ct:pal("✅ Update verified in read model"),
    ct:pal("🎉 Complete CQRS update flow verified!"),

    ok.

test_capability_retract_flow(_Config) ->
    ct:pal("Testing capability retract flow..."),

    %% First announce a capability
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

    %% Verify it exists
    {ok, _} = find_capability:execute(MRI),

    %% 1. Create retract command
    {ok, RetractCmd} = retract_capability_v1:new(MRI, AgentID, <<"No longer needed">>),

    %% 2. Handle retract command
    ct:pal("Handling retract_capability command..."),
    {ok, Events} = maybe_retract_capability:handle(RetractCmd),

    ?assertEqual(1, length(Events)),
    [Event] = Events,

    EventMap = capability_retracted_v1:to_map(Event),
    ?assertEqual(<<"capability_retracted_v1">>, maps:get(event_type, EventMap)),

    ct:pal("✅ Retract command handled"),

    %% 3. Project retract event
    ct:pal("Projecting retract event..."),
    ok = capability_retracted_v1_to_capabilities:project(EventMap),

    ct:pal("✅ Retract projected"),

    %% 4. Verify it's no longer in active list
    ct:pal("Verifying retraction..."),
    {ok, AllCapabilities} = list_capabilities:execute(),

    RetractedFound = lists:any(
        fun(#{mri := M}) -> M =:= MRI end,
        AllCapabilities
    ),

    ?assertNot(RetractedFound),

    ct:pal("✅ Retracted capability excluded from list"),
    ct:pal("🎉 Complete CQRS retract flow verified!"),

    ok.

test_subscription_flow(_Config) ->
    ct:pal("Testing subscription flow..."),

    %% 1. Create subscribe command
    Agent = <<"mri:agent:io.macula/subscriber-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Topic = <<"hecate.test.topic">>,

    Cmd = subscribe_v1:new(Agent, Topic, undefined, erlang:system_time(millisecond)),

    %% 2. Handle command
    ct:pal("Handling subscribe command..."),
    {ok, Events} = maybe_subscribe:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    %% Events from handle are already maps
    ?assertEqual(<<"subscribed_v1">>, maps:get(event_type, EventMap)),

    ct:pal("✅ Subscribe command handled"),

    %% 3. Project event
    ct:pal("Projecting subscription event..."),
    ok = subscribed_v1_to_subscriptions:project(EventMap),

    ct:pal("✅ Subscription projected"),

    %% 4. Query subscriptions
    ct:pal("Querying subscriptions..."),
    {ok, Subscriptions} = get_subscriptions:execute(Agent),

    ?assert(length(Subscriptions) > 0),

    TopicFound = lists:any(
        fun(#{topic := T}) -> T =:= Topic end,
        Subscriptions
    ),

    ?assert(TopicFound),

    ct:pal("✅ Subscription found in read model"),
    ct:pal("🎉 Complete CQRS subscription flow verified!"),

    ok.

test_identity_flow(_Config) ->
    ct:pal("Testing identity registration flow..."),

    %% 1. Create register_identity command
    MRI = <<"mri:agent:io.macula/test-identity-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    PublicKey = <<"base64encodedkey123">>,

    Cmd = register_identity_v1:new(
        MRI,
        PublicKey,
        <<"ed25519">>,
        #{},
        erlang:system_time(millisecond)
    ),

    %% 2. Handle command
    ct:pal("Handling register_identity command..."),
    {ok, Events} = maybe_register_identity:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    %% Events from handle are already maps
    ?assertEqual(<<"identity_registered_v1">>, maps:get(event_type, EventMap)),

    ct:pal("✅ Identity registration command handled"),

    %% 3. Project event
    ct:pal("Projecting identity event..."),
    ok = identity_registered_v1_to_identities:project(EventMap),

    ct:pal("✅ Identity projected"),

    %% 4. Query identity
    ct:pal("Querying identity..."),
    {ok, Identity} = find_identity:execute(MRI),

    ?assertEqual(MRI, maps:get(mri, Identity)),
    ?assertEqual(PublicKey, maps:get(public_key, Identity)),
    ?assertEqual(<<"ed25519">>, maps:get(key_type, Identity)),

    ct:pal("✅ Identity found in read model"),
    ct:pal("🎉 Complete CQRS identity flow verified!"),

    ok.

test_ucan_flow(_Config) ->
    ct:pal("Testing UCAN capability flow..."),

    %% 1. Create grant_capability command
    CapID = <<"cap-test-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Issuer = <<"mri:agent:io.macula/issuer">>,
    Audience = <<"mri:agent:io.macula/recipient-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Now = erlang:system_time(millisecond),
    ExpiresAt = Now + 86400000, %% 24 hours

    Cmd = grant_capability_v1:new(
        CapID,
        Issuer,
        Audience,
        <<"mri:resource:io.macula/test-resource">>,
        [<<"read">>, <<"write">>],
        ExpiresAt,
        Now
    ),

    %% 2. Handle command
    ct:pal("Handling grant_capability command..."),
    {ok, Events} = maybe_grant_capability:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    %% Events from handle are already maps
    ?assertEqual(<<"capability_granted_v1">>, maps:get(event_type, EventMap)),

    ct:pal("✅ Grant capability command handled"),

    %% 3. Project event
    ct:pal("Projecting capability grant..."),
    ok = capability_granted_v1_to_capabilities:project(EventMap),

    ct:pal("✅ Capability grant projected"),

    %% 4. Query capabilities
    ct:pal("Querying capabilities for audience..."),
    {ok, Capabilities} = find_capabilities:by_audience(Audience),

    ?assert(length(Capabilities) > 0),

    CapFound = lists:any(
        fun(#{capability_id := CID}) -> CID =:= CapID end,
        Capabilities
    ),

    ?assert(CapFound),

    ct:pal("✅ Capability found in read model"),
    ct:pal("🎉 Complete CQRS UCAN flow verified!"),

    ok.

test_social_follow_flow(_Config) ->
    ct:pal("Testing social follow flow..."),

    %% 1. Create follow command
    Follower = <<"mri:agent:io.macula/follower-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Followed = <<"mri:agent:io.macula/followed-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,

    Cmd = follow_agent_v1:new(Follower, Followed),

    %% 2. Handle command
    ct:pal("Handling follow_agent command..."),
    {ok, Events} = maybe_follow_agent:handle(Cmd),

    ?assertEqual(1, length(Events)),
    [EventMap] = Events,

    %% Events from handle are already maps
    ?assertEqual(<<"agent_followed_v1">>, maps:get(event_type, EventMap)),

    ct:pal("✅ Follow command handled"),

    %% 3. Project event
    ct:pal("Projecting follow event..."),
    ok = agent_followed_v1_to_followers:project(EventMap),

    ct:pal("✅ Follow projected"),

    %% 4. Query following
    ct:pal("Querying following list..."),
    {ok, Following} = get_following:execute(Follower),

    ?assert(length(Following) > 0),

    FollowedFound = lists:any(
        fun(#{followed_identity := F}) -> F =:= Followed end,
        Following
    ),

    ?assert(FollowedFound),

    ct:pal("✅ Follow relationship found in read model"),
    ct:pal("🎉 Complete CQRS social flow verified!"),

    ok.
