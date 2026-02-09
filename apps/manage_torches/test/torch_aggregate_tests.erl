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

%% ============================================================
%% Helper: create an initiated torch state (INITIATED | DNA_ACTIVE)
%% ============================================================
initiated_state() ->
    InitialState = torch_aggregate:initial_state(),
    {ok, [EventMap]} = torch_aggregate:execute(InitialState, #{
        command_type => <<"initiate_torch">>,
        torch_id => <<"torch-vision-test">>,
        name => <<"Vision Test Torch">>,
        brief => <<"Original brief">>,
        repos => [<<"repo-a">>],
        skills => [<<"skill-a">>]
    }),
    torch_aggregate:apply_event(EventMap, InitialState).

%% ============================================================
%% refine_vision tests
%% ============================================================

%% Refine vision succeeds on an initiated torch (DNA_ACTIVE)
refine_vision_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => <<"refine_vision">>,
        torch_id => <<"torch-vision-test">>,
        brief => <<"Refined brief">>,
        refined_by => <<"rl@host00">>
    },

    Result = torch_aggregate:execute(State, Payload),
    ?assertMatch({ok, [_]}, Result),

    {ok, [EventMap]} = Result,
    ?assertEqual(<<"torch_vision_refined_v1">>, maps:get(<<"event_type">>, EventMap)),
    ?assertEqual(<<"Refined brief">>, maps:get(<<"brief">>, EventMap)),
    ?assertEqual(<<"rl@host00">>, maps:get(<<"refined_by">>, EventMap)).

%% Refine vision applies partial updates (only provided fields change)
refine_vision_partial_update_test() ->
    State = initiated_state(),

    %% Only update repos, leave brief/skills/context_map untouched
    {ok, [EventMap]} = torch_aggregate:execute(State, #{
        command_type => <<"refine_vision">>,
        torch_id => <<"torch-vision-test">>,
        repos => [<<"repo-b">>, <<"repo-c">>]
    }),

    NewState = torch_aggregate:apply_event(EventMap, State),

    %% brief should remain original
    ?assertEqual(<<"Original brief">>, element(4, NewState)),  %% #torch_state.brief
    %% But we can also verify by refining again and checking brief survives
    {ok, [EventMap2]} = torch_aggregate:execute(NewState, #{
        command_type => <<"refine_vision">>,
        torch_id => <<"torch-vision-test">>,
        skills => [<<"skill-x">>]
    }),
    FinalState = torch_aggregate:apply_event(EventMap2, NewState),

    %% repos should be from first refinement, skills from second
    ?assertEqual([<<"repo-b">>, <<"repo-c">>], element(6, FinalState)),  %% repos
    ?assertEqual([<<"skill-x">>], element(7, FinalState)).               %% skills

%% Refine vision fails on uninitiated torch
refine_vision_not_initiated_test() ->
    State = torch_aggregate:initial_state(),
    Payload = #{
        command_type => <<"refine_vision">>,
        torch_id => <<"torch-vision-test">>
    },
    Result = torch_aggregate:execute(State, Payload),
    ?assertEqual({error, torch_not_found}, Result).

%% Refine vision fails on archived torch
refine_vision_archived_test() ->
    State = initiated_state(),

    %% Archive it
    {ok, [ArchiveEvent]} = torch_aggregate:execute(State, #{
        command_type => <<"archive_torch">>,
        torch_id => <<"torch-vision-test">>
    }),
    ArchivedState = torch_aggregate:apply_event(ArchiveEvent, State),

    Result = torch_aggregate:execute(ArchivedState, #{
        command_type => <<"refine_vision">>,
        torch_id => <<"torch-vision-test">>
    }),
    ?assertEqual({error, torch_archived}, Result).

%% Refine vision fails after DnA is complete (DNA_ACTIVE unset)
refine_vision_dna_complete_test() ->
    State = initiated_state(),

    %% Submit vision to complete DnA
    {ok, [SubmitEvent]} = torch_aggregate:execute(State, #{
        command_type => <<"submit_vision">>,
        torch_id => <<"torch-vision-test">>
    }),
    DnaCompleteState = torch_aggregate:apply_event(SubmitEvent, State),

    Result = torch_aggregate:execute(DnaCompleteState, #{
        command_type => <<"refine_vision">>,
        torch_id => <<"torch-vision-test">>
    }),
    ?assertEqual({error, dna_not_active}, Result).

%% ============================================================
%% submit_vision tests
%% ============================================================

%% Submit vision succeeds on an initiated torch (DNA_ACTIVE)
submit_vision_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => <<"submit_vision">>,
        torch_id => <<"torch-vision-test">>,
        submitted_by => <<"rl@host00">>
    },

    Result = torch_aggregate:execute(State, Payload),
    ?assertMatch({ok, [_]}, Result),

    {ok, [EventMap]} = Result,
    ?assertEqual(<<"torch_vision_submitted_v1">>, maps:get(<<"event_type">>, EventMap)),
    ?assertEqual(<<"rl@host00">>, maps:get(<<"submitted_by">>, EventMap)).

%% Submit vision transitions DNA_ACTIVE -> DNA_COMPLETE
submit_vision_status_transition_test() ->
    State = initiated_state(),

    {ok, [EventMap]} = torch_aggregate:execute(State, #{
        command_type => <<"submit_vision">>,
        torch_id => <<"torch-vision-test">>
    }),
    NewState = torch_aggregate:apply_event(EventMap, State),

    %% Status should have INITIATED (1) | DNA_COMPLETE (4) = 5
    %% DNA_ACTIVE (2) should be unset
    Status = element(5, NewState),  %% #torch_state.status
    ?assertEqual(0, Status band 2),   %% DNA_ACTIVE unset
    ?assertNotEqual(0, Status band 4), %% DNA_COMPLETE set
    ?assertNotEqual(0, Status band 1). %% INITIATED still set

%% Submit vision fails on uninitiated torch
submit_vision_not_initiated_test() ->
    State = torch_aggregate:initial_state(),
    Payload = #{
        command_type => <<"submit_vision">>,
        torch_id => <<"torch-vision-test">>
    },
    Result = torch_aggregate:execute(State, Payload),
    ?assertEqual({error, torch_not_found}, Result).

%% Submit vision fails on archived torch
submit_vision_archived_test() ->
    State = initiated_state(),

    {ok, [ArchiveEvent]} = torch_aggregate:execute(State, #{
        command_type => <<"archive_torch">>,
        torch_id => <<"torch-vision-test">>
    }),
    ArchivedState = torch_aggregate:apply_event(ArchiveEvent, State),

    Result = torch_aggregate:execute(ArchivedState, #{
        command_type => <<"submit_vision">>,
        torch_id => <<"torch-vision-test">>
    }),
    ?assertEqual({error, torch_archived}, Result).

%% Submit vision fails if already complete (double submit)
submit_vision_already_complete_test() ->
    State = initiated_state(),

    {ok, [SubmitEvent]} = torch_aggregate:execute(State, #{
        command_type => <<"submit_vision">>,
        torch_id => <<"torch-vision-test">>
    }),
    CompletedState = torch_aggregate:apply_event(SubmitEvent, State),

    Result = torch_aggregate:execute(CompletedState, #{
        command_type => <<"submit_vision">>,
        torch_id => <<"torch-vision-test">>
    }),
    ?assertEqual({error, dna_not_active}, Result).
