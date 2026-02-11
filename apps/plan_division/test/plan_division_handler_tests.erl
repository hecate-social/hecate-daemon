%%% @doc Layer 2b+2c: Handler + Aggregate execute/2 tests.
%%% Tests handle/1 business logic and execute/2 state machine guards.
%%% No I/O -- builds state via apply/2 chains, then tests commands.
-module(plan_division_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("plan_division/include/plan_status.hrl").

-compile(nowarn_unused_function).

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = plan_aggregate:init(<<"x">>),
    S.

started_state() ->
    plan_aggregate:apply(fresh_state(), start_event_map()).

active_with_desk_state() ->
    S = started_state(),
    plan_aggregate:apply(S, desk_planned_event_map()).

paused_state() ->
    plan_aggregate:apply(started_state(), pause_event_map()).

completed_state() ->
    plan_aggregate:apply(started_state(), complete_event_map()).

archived_state() ->
    plan_aggregate:apply(started_state(), archive_event_map()).

start_event_map() ->
    #{<<"event_type">> => <<"plan_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

desk_planned_event_map() ->
    #{<<"event_type">> => <<"desk_planned_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"desk_id">> => <<"desk-001">>,
      <<"desk_name">> => <<"register_user">>,
      <<"department">> => <<"CMD">>,
      <<"description">> => <<"Register user">>,
      <<"priority">> => 1,
      <<"planned_at">> => 2000}.

dependency_planned_event_map() ->
    #{<<"event_type">> => <<"dependency_planned_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"dependency_id">> => <<"dep-001">>,
      <<"from_desk">> => <<"register_user">>,
      <<"to_desk">> => <<"send_welcome_email">>,
      <<"dependency_type">> => <<"triggers">>,
      <<"planned_at">> => 3000}.

pause_event_map() ->
    #{<<"event_type">> => <<"plan_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"needs review">>}.

resume_event_map() ->
    #{<<"event_type">> => <<"plan_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 5000}.

complete_event_map() ->
    #{<<"event_type">> => <<"plan_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event_map() ->
    #{<<"event_type">> => <<"plan_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% --- maybe_start_plan ---

handle_valid_start_test() ->
    {ok, Cmd} = start_plan_v1:new(#{
        division_id => <<"div-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_plan:handle(Cmd),
    Map = plan_started_v1:to_map(Event),
    ?assertEqual(<<"plan_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)).

%% --- maybe_plan_desk ---

handle_valid_plan_desk_test() ->
    {ok, Cmd} = plan_desk_v1:new(#{
        division_id => <<"div-1">>,
        desk_name => <<"register_user">>,
        department => <<"CMD">>,
        description => <<"Register a user">>,
        priority => 1,
        planned_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_plan_desk:handle(Cmd, #{planned_desks => #{}}),
    Map = desk_planned_v1:to_map(Event),
    ?assertEqual(<<"desk_planned_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"register_user">>, maps:get(<<"desk_name">>, Map)),
    ?assertEqual(<<"CMD">>, maps:get(<<"department">>, Map)).

handle_plan_desk_duplicate_test() ->
    {ok, Cmd} = plan_desk_v1:new(#{
        division_id => <<"div-1">>,
        desk_name => <<"register_user">>
    }),
    Existing = #{<<"register_user">> => #{desk_name => <<"register_user">>}},
    ?assertEqual({error, desk_already_planned},
                 maybe_plan_desk:handle(Cmd, #{planned_desks => Existing})).

%% --- maybe_plan_dependency ---

handle_valid_plan_dependency_test() ->
    {ok, Cmd} = plan_dependency_v1:new(#{
        division_id => <<"div-1">>,
        from_desk => <<"register_user">>,
        to_desk => <<"send_welcome_email">>,
        dependency_type => <<"triggers">>,
        description => <<"Triggers welcome email">>,
        planned_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_plan_dependency:handle(Cmd),
    Map = dependency_planned_v1:to_map(Event),
    ?assertEqual(<<"dependency_planned_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"register_user">>, maps:get(<<"from_desk">>, Map)),
    ?assertEqual(<<"send_welcome_email">>, maps:get(<<"to_desk">>, Map)).

%% --- maybe_pause_plan ---

handle_valid_pause_test() ->
    {ok, Cmd} = pause_plan_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"needs review">>
    }),
    {ok, [Event]} = maybe_pause_plan:handle(Cmd),
    Map = plan_paused_v1:to_map(Event),
    ?assertEqual(<<"plan_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"needs review">>, maps:get(<<"reason">>, Map)).

%% --- maybe_resume_plan ---

handle_valid_resume_test() ->
    {ok, Cmd} = resume_plan_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_resume_plan:handle(Cmd),
    Map = plan_resumed_v1:to_map(Event),
    ?assertEqual(<<"plan_resumed_v1">>, maps:get(<<"event_type">>, Map)).

%% --- maybe_complete_plan ---

handle_valid_complete_test() ->
    {ok, Cmd} = complete_plan_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_complete_plan:handle(Cmd),
    Map = plan_completed_v1:to_map(Event),
    ?assertEqual(<<"plan_completed_v1">>, maps:get(<<"event_type">>, Map)).

%% --- maybe_archive_plan ---

handle_valid_archive_test() ->
    {ok, Cmd} = archive_plan_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_plan:handle(Cmd),
    Map = plan_archived_v1:to_map(Event),
    ?assertEqual(<<"plan_archived_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_plan command ---

execute_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"start_plan">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = plan_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"plan_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_already_started_test() ->
    Cmd = #{<<"command_type">> => <<"start_plan">>,
            <<"division_id">> => <<"div-2">>},
    %% On started state, start_plan is not recognized (goes to execute_lifecycle
    %% which has no clause for start_plan, so falls through to unknown_command)
    Result = plan_aggregate:execute(started_state(), Cmd),
    ?assertMatch({error, _}, Result).

%% --- plan_desk command ---

execute_plan_desk_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"plan_desk">>,
            <<"division_id">> => <<"div-1">>,
            <<"desk_name">> => <<"register_user">>,
            <<"department">> => <<"CMD">>},
    {ok, [EventMap]} = plan_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"desk_planned_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_plan_desk_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"plan_desk">>,
            <<"division_id">> => <<"div-1">>,
            <<"desk_name">> => <<"register_user">>},
    ?assertEqual({error, plan_not_started},
                 plan_aggregate:execute(fresh_state(), Cmd)).

execute_plan_desk_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"plan_desk">>,
            <<"division_id">> => <<"div-1">>,
            <<"desk_name">> => <<"register_user">>},
    State = paused_state(),
    ?assertMatch({error, {not_active, _}},
                 plan_aggregate:execute(State, Cmd)).

%% --- plan_dependency command ---

execute_plan_dependency_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"plan_dependency">>,
            <<"division_id">> => <<"div-1">>,
            <<"from_desk">> => <<"register_user">>,
            <<"to_desk">> => <<"send_welcome_email">>,
            <<"dependency_type">> => <<"triggers">>},
    {ok, [EventMap]} = plan_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"dependency_planned_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_plan_dependency_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"plan_dependency">>,
            <<"division_id">> => <<"div-1">>,
            <<"from_desk">> => <<"a">>,
            <<"to_desk">> => <<"b">>,
            <<"dependency_type">> => <<"triggers">>},
    ?assertMatch({error, {not_active, _}},
                 plan_aggregate:execute(paused_state(), Cmd)).

%% --- pause_plan command ---

execute_pause_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_plan">>,
            <<"division_id">> => <<"div-1">>,
            <<"reason">> => <<"review">>},
    {ok, [EventMap]} = plan_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"plan_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"pause_plan">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 plan_aggregate:execute(paused_state(), Cmd)).

%% --- resume_plan command ---

execute_resume_on_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_plan">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = plan_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"plan_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_not_paused_test() ->
    Cmd = #{<<"command_type">> => <<"resume_plan">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_paused, _}},
                 plan_aggregate:execute(started_state(), Cmd)).

%% --- complete_plan command ---

execute_complete_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_plan">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = plan_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"plan_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_not_active_test() ->
    Cmd = #{<<"command_type">> => <<"complete_plan">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 plan_aggregate:execute(paused_state(), Cmd)).

%% --- archive_plan command ---

execute_archive_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_plan">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = plan_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"plan_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_plan">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, plan_archived},
                 plan_aggregate:execute(archived_state(), Cmd)).

execute_archive_not_started_test() ->
    Cmd = #{<<"command_type">> => <<"archive_plan">>,
            <<"division_id">> => <<"div-1">>},
    %% Fresh state (status=0), PLAN_INITIATED is not set, so the archive
    %% guard fails and falls through to the catch-all
    ?assertMatch({error, _},
                 plan_aggregate:execute(fresh_state(), Cmd)).

%% Archive on completed state should work (initiated and not archived)
execute_archive_on_completed_test() ->
    Cmd = #{<<"command_type">> => <<"archive_plan">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = plan_aggregate:execute(completed_state(), Cmd),
    ?assertEqual(<<"plan_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

%% Archive on paused state should work (initiated and not archived)
execute_archive_on_paused_test() ->
    Cmd = #{<<"command_type">> => <<"archive_plan">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = plan_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"plan_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

%% --- unknown command ---

execute_unknown_command_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, plan_not_started},
                 plan_aggregate:execute(fresh_state(), Cmd)).

execute_unknown_command_on_started_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 plan_aggregate:execute(started_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertMatch({error, _},
                 plan_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_plan">>,
                <<"division_id">> => <<"div-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = plan_aggregate:execute(State, Payload).
