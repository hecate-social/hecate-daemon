%%% @doc Integration tests for query_capabilities service
-module(query_capabilities_test).

-include_lib("eunit/include/eunit.hrl").

%% Test event deserialization from map
event_deserialization_test() ->
    EventMap = #{
        type => <<"capability_announced_v1">>,
        capability_mri => <<"mri:capability:io.macula/test">>,
        agent_identity => <<"did:macula:test">>,
        tags => [<<"test">>],
        description => <<"Test capability">>,
        demo_procedure => null,
        metadata => #{},
        announced_at => 1234567890
    },

    {ok, Event} = capability_announced_v1:from_map(EventMap),

    ?assertEqual(<<"mri:capability:io.macula/test">>,
                 capability_announced_v1:get_mri(Event)),
    ?assertEqual(<<"did:macula:test">>,
                 capability_announced_v1:get_agent_id(Event)),
    ?assertEqual([<<"test">>],
                 capability_announced_v1:get_tags(Event)).

%% Test query service depends on command service for event schemas
dependency_test() ->
    %% Verify we can access event types from manage_capabilities
    Event = capability_announced_v1:new(
        <<"mri:capability:io.macula/calculator">>,
        <<"did:macula:agent123">>,
        [<<"math">>, <<"calculator">>],
        <<"Scientific calculator service">>,
        <<"calculator.demo">>,
        #{version => <<"1.0.0">>}
    ),

    %% Verify accessors work
    ?assertEqual(<<"mri:capability:io.macula/calculator">>,
                 capability_announced_v1:get_mri(Event)),
    ?assertEqual(2, length(capability_announced_v1:get_tags(Event))).
