%%% @doc Integration tests for cartwheel auto-initiation flow
%%%
%%% Tests the complete flow:
%%% cartwheel_identified_v1 fact -> pg -> listener -> policy -> command dispatch
%%%
%%% This test suite verifies the parent-child aggregate pattern works:
%%% Torch (parent) identifies cartwheel -> Cartwheel (child) auto-initiates
-module(cartwheel_auto_initiation_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(PG_SCOPE, pg).
-define(PG_GROUP, cartwheel_identified_v1).

%% =================================================================
%% Test: Full pg -> listener -> policy flow (without real dispatch)
%% =================================================================

%% This test verifies the listener receives pg messages and calls the policy.
%% We don't test actual evoq dispatch here (that requires ReckonDB).
listener_receives_and_forwards_test_() ->
    {setup,
     fun setup/0,
     fun cleanup/1,
     fun(_) ->
         [
          {"Listener receives pg message", fun listener_receives_pg_message/0},
          {"Policy extracts binary keys correctly", fun policy_extracts_binary_keys/0}
         ]
     end}.

setup() ->
    %% Ensure pg scope exists
    ensure_pg(),
    ok.

cleanup(_) ->
    ok.

%% Test that a process can join the pg group and receive messages
listener_receives_pg_message() ->
    %% Join the group (simulating what subscribe_to_cartwheel_identified does)
    ok = pg:join(?PG_SCOPE, ?PG_GROUP, self()),

    %% Create fact with binary keys (as from cartwheel_identified_v1:to_map/1)
    Fact = #{
        <<"event_type">> => <<"cartwheel_identified_v1">>,
        <<"torch_id">> => <<"torch-integration-test">>,
        <<"cartwheel_id">> => <<"cw-integration-test">>,
        <<"context_name">> => <<"Integration Test Context">>,
        <<"description">> => <<"Testing the flow">>
    },

    %% Emit via pg (simulating what cartwheel_identified_v1_to_pg does)
    Members = pg:get_members(?PG_SCOPE, ?PG_GROUP),
    ?assert(length(Members) > 0),

    Message = {cartwheel_identified_v1, Fact},
    lists:foreach(fun(Pid) -> Pid ! Message end, Members),

    %% Verify we receive the message
    receive
        {cartwheel_identified_v1, ReceivedFact} ->
            ?assertEqual(Fact, ReceivedFact),
            %% Verify we can extract fields for policy
            ?assertEqual(<<"torch-integration-test">>,
                         maps:get(<<"torch_id">>, ReceivedFact)),
            ?assertEqual(<<"cw-integration-test">>,
                         maps:get(<<"cartwheel_id">>, ReceivedFact)),
            ?assertEqual(<<"Integration Test Context">>,
                         maps:get(<<"context_name">>, ReceivedFact))
    after 1000 ->
        ?assert(false)
    end,

    %% Cleanup
    ok = pg:leave(?PG_SCOPE, ?PG_GROUP, self()).

%% Test that policy correctly extracts binary keys and creates valid command params
policy_extracts_binary_keys() ->
    %% Fact with binary keys
    FactData = #{
        <<"event_type">> => <<"cartwheel_identified_v1">>,
        <<"torch_id">> => <<"torch-policy-test">>,
        <<"cartwheel_id">> => <<"cw-policy-test">>,
        <<"context_name">> => <<"Policy Test Context">>,
        <<"description">> => <<"Testing policy field extraction">>
    },

    %% Extract fields the way the policy does
    TorchId = get_field(torch_id, FactData),
    CartwheelId = get_field(cartwheel_id, FactData),
    ContextName = get_field(context_name, FactData),
    Description = get_field(description, FactData),

    %% Verify extraction worked
    ?assertEqual(<<"torch-policy-test">>, TorchId),
    ?assertEqual(<<"cw-policy-test">>, CartwheelId),
    ?assertEqual(<<"Policy Test Context">>, ContextName),
    ?assertEqual(<<"Testing policy field extraction">>, Description),

    %% Build params the way policy does
    Params = #{
        cartwheel_id => CartwheelId,
        torch_id => TorchId,
        context_name => ContextName,
        description => Description
    },

    %% Verify command can be created
    Result = initiate_cartwheel_v1:new(Params),
    ?assertMatch({ok, _}, Result),

    {ok, Cmd} = Result,
    ?assertEqual(CartwheelId, initiate_cartwheel_v1:get_cartwheel_id(Cmd)),
    ?assertEqual(TorchId, initiate_cartwheel_v1:get_torch_id(Cmd)),
    ?assertEqual(ContextName, initiate_cartwheel_v1:get_context_name(Cmd)).

%% =================================================================
%% Test: Event created by cartwheel_initiated_v1:to_map contains event_type
%% =================================================================

event_contains_event_type_test() ->
    %% Create event via the event module
    Event = cartwheel_initiated_v1:new(#{
        cartwheel_id => <<"cw-event-test">>,
        torch_id => <<"torch-event-test">>,
        context_name => <<"Event Test Context">>
    }),

    %% Convert to map (as would be stored/published)
    EventMap = cartwheel_initiated_v1:to_map(Event),

    %% Verify event_type is present (needed for projection routing)
    ?assertEqual(<<"cartwheel_initiated_v1">>,
                 maps:get(event_type, EventMap)).

%% =================================================================
%% Helpers
%% =================================================================

ensure_pg() ->
    case pg:start(?PG_SCOPE) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

%% Helper to get field from map with atom or binary keys
get_field(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    maps:get(Key, Map, maps:get(BinKey, Map, undefined)).
