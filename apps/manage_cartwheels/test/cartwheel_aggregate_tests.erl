%%% @doc Tests for cartwheel_aggregate
%%%
%%% Verifies the aggregate handles commands correctly.
%%% CRITICAL: Tests the execute/2 function signature matches evoq expectations.
-module(cartwheel_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test that execute/2 has correct argument order (State, Payload)
%% evoq_aggregate.erl calls: Module:execute(AggState, Command#evoq_command.payload)
%% So aggregate must be: execute(State, Payload) NOT execute(Payload, State)
execute_argument_order_test() ->
    %% Initial state
    State = cartwheel_aggregate:initial_state(),

    %% Command payload (as produced by initiate_cartwheel_v1:to_map/1)
    Payload = #{
        command_type => <<"initiate_cartwheel">>,
        cartwheel_id => <<"cw-test-123">>,
        torch_id => <<"torch-test-456">>,
        context_name => <<"Test Context">>,
        description => <<"A test cartwheel">>
    },

    %% Execute with correct argument order: State, Payload
    Result = cartwheel_aggregate:execute(State, Payload),

    %% Should return {ok, [EventMap]}
    ?assertMatch({ok, [_]}, Result),

    {ok, [EventMap]} = Result,
    ?assertEqual(<<"cartwheel_initiated_v1">>, maps:get(event_type, EventMap)),
    ?assertEqual(<<"cw-test-123">>, maps:get(cartwheel_id, EventMap)),
    ?assertEqual(<<"Test Context">>, maps:get(context_name, EventMap)).

%% Test that unknown command returns error
unknown_command_test() ->
    State = cartwheel_aggregate:initial_state(),
    Payload = #{command_type => <<"unknown_command">>},

    Result = cartwheel_aggregate:execute(State, Payload),
    ?assertEqual({error, unknown_command}, Result).

%% Test that double-initiate returns error
double_initiate_test() ->
    %% First initiate
    InitialState = cartwheel_aggregate:initial_state(),
    Payload = #{
        command_type => <<"initiate_cartwheel">>,
        cartwheel_id => <<"cw-test">>,
        context_name => <<"Test">>
    },

    {ok, [EventMap]} = cartwheel_aggregate:execute(InitialState, Payload),

    %% Apply event to get new state
    NewState = cartwheel_aggregate:apply_event(EventMap, InitialState),

    %% Try to initiate again - should fail
    Result = cartwheel_aggregate:execute(NewState, Payload),
    ?assertEqual({error, cartwheel_already_initiated}, Result).

%% Test apply_event updates state correctly
apply_event_test() ->
    State = cartwheel_aggregate:initial_state(),

    EventMap = #{
        event_type => <<"cartwheel_initiated_v1">>,
        cartwheel_id => <<"cw-123">>,
        torch_id => <<"torch-456">>,
        context_name => <<"My Context">>,
        initiated_at => 123456789
    },

    NewState = cartwheel_aggregate:apply_event(EventMap, State),

    %% Verify state was updated (can't directly inspect record, but status should be non-zero)
    ?assertNotEqual(State, NewState).
