%%% @doc Integration test for capability announcement
-module(capability_announce_test).

-include_lib("eunit/include/eunit.hrl").

%% Test command creation and validation
command_creation_test() ->
    Cmd = #{
        capability_mri => <<"mri:capability:io.macula/weather/forecast">>,
        agent_identity => <<"did:macula:agent123">>,
        tags => [<<"weather">>, <<"forecast">>],
        description => <<"Weather forecasting service">>
    },
    {ok, CmdRec} = announce_capability_v1:new(Cmd),
    ?assertEqual(<<"mri:capability:io.macula/weather/forecast">>,
                 announce_capability_v1:get_mri(CmdRec)).

%% Test event creation from command
event_from_command_test() ->
    Cmd = #{
        capability_mri => <<"mri:capability:io.macula/test">>,
        agent_identity => <<"did:macula:test">>,
        tags => [<<"test">>],
        description => <<"Test capability">>
    },
    {ok, CmdRec} = announce_capability_v1:new(Cmd),
    {ok, [Event]} = maybe_announce_capability:handle(CmdRec),

    ?assertEqual(<<"mri:capability:io.macula/test">>,
                 capability_announced_v1:get_mri(Event)),
    ?assertEqual(<<"did:macula:test">>,
                 capability_announced_v1:get_agent_id(Event)),
    ?assertEqual([<<"test">>],
                 capability_announced_v1:get_tags(Event)).

%% Test event serialization round-trip
event_serialization_test() ->
    Event = capability_announced_v1:new(
        <<"mri:capability:io.macula/test">>,
        <<"did:macula:agent1">>,
        [<<"tag1">>, <<"tag2">>],
        <<"Test description">>,
        <<"demo_proc">>,
        #{custom => <<"data">>}
    ),

    Map = capability_announced_v1:to_map(Event),
    {ok, Event2} = capability_announced_v1:from_map(Map),

    ?assertEqual(capability_announced_v1:get_mri(Event),
                 capability_announced_v1:get_mri(Event2)).

%% Test aggregate state application
aggregate_state_test() ->
    InitialState = capability_aggregate:initial_state(),

    Event = capability_announced_v1:new(
        <<"mri:capability:io.macula/calc">>,
        <<"did:macula:agent99">>,
        [<<"math">>],
        <<"Calculator service">>,
        undefined,
        #{}
    ),

    %% Aggregate expects map (evoq passes events as maps)
    EventMap = capability_announced_v1:to_map(Event),
    NewState = capability_aggregate:apply_event(EventMap, InitialState),

    %% Verify state was updated (we can't directly inspect the record,
    %% but we can test that applying the event doesn't crash)
    ?assertNotEqual(InitialState, NewState).
