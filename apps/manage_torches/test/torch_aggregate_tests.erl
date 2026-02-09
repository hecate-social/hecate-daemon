%%% @doc Tests for torch_aggregate
%%%
%%% Verifies the aggregate handles commands correctly.
%%% CRITICAL: Tests the execute/2 function signature matches evoq expectations.
-module(torch_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test that execute/2 has correct argument order (State, Payload)
%% evoq_aggregate.erl calls: Module:execute(AggState, Command#evoq_command.payload)
execute_argument_order_test() ->
    %% Initial state
    State = torch_aggregate:initial_state(),

    %% Command payload (as produced by initiate_torch_v1:to_map/1)
    Payload = #{
        command_type => <<"initiate_torch">>,
        torch_id => <<"torch-test-123">>,
        name => <<"Test Torch">>,
        brief => <<"A test torch">>
    },

    %% Execute with correct argument order: State, Payload
    Result = torch_aggregate:execute(State, Payload),

    %% Should return {ok, [EventMap]}
    ?assertMatch({ok, [_]}, Result),

    {ok, [EventMap]} = Result,
    ?assertEqual(<<"torch_initiated_v1">>, maps:get(<<"event_type">>, EventMap)),
    ?assertEqual(<<"Test Torch">>, maps:get(<<"name">>, EventMap)).

%% Test that unknown command returns error
unknown_command_test() ->
    State = torch_aggregate:initial_state(),
    Payload = #{command_type => <<"unknown_command">>},

    Result = torch_aggregate:execute(State, Payload),
    ?assertEqual({error, unknown_command}, Result).

%% Test that double-initiate returns error
double_initiate_test() ->
    InitialState = torch_aggregate:initial_state(),
    Payload = #{
        command_type => <<"initiate_torch">>,
        torch_id => <<"torch-test">>,
        name => <<"Test">>
    },

    {ok, [EventMap]} = torch_aggregate:execute(InitialState, Payload),

    %% Apply event to get new state
    NewState = torch_aggregate:apply_event(EventMap, InitialState),

    %% Try to initiate again - should fail
    Result = torch_aggregate:execute(NewState, Payload),
    ?assertEqual({error, torch_already_initiated}, Result).
