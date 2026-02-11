%%% @doc Layer 2b+2c: Handler + Aggregate execute/2 tests.
%%% Tests handle/1 business logic and execute/2 state machine guards.
%%% No I/O -- builds state via apply/2 chains, then tests commands.
%%%
%%% rescue_state fields:
%%%   1=record_tag, 2=division_id, 3=incident_id, 4=status,
%%%   5=diagnoses, 6=fixes, 7=started_at, 8=paused_at,
%%%   9=completed_at, 10=pause_reason
-module(rescue_division_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("rescue_division/include/rescue_status.hrl").

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    {ok, S} = rescue_aggregate:init(<<"any-id">>),
    S.

started_state() ->
    rescue_aggregate:apply(fresh_state(), start_event_map()).

paused_state() ->
    rescue_aggregate:apply(started_state(), pause_event_map()).

completed_state() ->
    rescue_aggregate:apply(started_state(), complete_event_map()).

archived_state() ->
    rescue_aggregate:apply(started_state(), archive_event_map()).

start_event_map() ->
    #{<<"event_type">> => <<"rescue_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"incident_id">> => <<"inc-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

pause_event_map() ->
    #{<<"event_type">> => <<"rescue_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 2000,
      <<"reason">> => <<"review">>}.

resume_event_map() ->
    #{<<"event_type">> => <<"rescue_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 3000}.

complete_event_map() ->
    #{<<"event_type">> => <<"rescue_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 4000}.

archive_event_map() ->
    #{<<"event_type">> => <<"rescue_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 5000,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"done">>}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% maybe_start_rescue: valid command produces rescue_started_v1
handle_valid_start_test() ->
    {ok, Cmd} = start_rescue_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        started_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_start_rescue:handle(Cmd),
    Map = rescue_started_v1:to_map(Event),
    ?assertEqual(<<"rescue_started_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"inc-1">>, maps:get(<<"incident_id">>, Map)),
    ?assertEqual(<<"user@host">>, maps:get(<<"started_by">>, Map)).

%% maybe_diagnose_incident: valid command produces incident_diagnosed_v1
handle_valid_diagnose_test() ->
    {ok, Cmd} = diagnose_incident_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        diagnosis => <<"Memory leak">>,
        root_cause => <<"Unbounded queue">>,
        diagnosed_by => <<"eng@host">>
    }),
    {ok, [Event]} = maybe_diagnose_incident:handle(Cmd),
    Map = incident_diagnosed_v1:to_map(Event),
    ?assertEqual(<<"incident_diagnosed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"inc-1">>, maps:get(<<"incident_id">>, Map)),
    ?assertEqual(<<"Memory leak">>, maps:get(<<"diagnosis">>, Map)),
    ?assertEqual(<<"Unbounded queue">>, maps:get(<<"root_cause">>, Map)),
    ?assert(is_binary(maps:get(<<"diagnosis_id">>, Map))).

%% maybe_apply_fix: valid command produces fix_applied_v1
handle_valid_apply_fix_test() ->
    {ok, Cmd} = apply_fix_v1:new(#{
        division_id => <<"div-1">>,
        incident_id => <<"inc-1">>,
        diagnosis_id => <<"diag-1">>,
        fix_description => <<"Added backpressure">>,
        fix_type => <<"hotfix">>,
        applied_by => <<"eng@host">>
    }),
    {ok, [Event]} = maybe_apply_fix:handle(Cmd),
    Map = fix_applied_v1:to_map(Event),
    ?assertEqual(<<"fix_applied_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"diag-1">>, maps:get(<<"diagnosis_id">>, Map)),
    ?assertEqual(<<"Added backpressure">>, maps:get(<<"fix_description">>, Map)),
    ?assertEqual(<<"hotfix">>, maps:get(<<"fix_type">>, Map)),
    ?assert(is_binary(maps:get(<<"fix_id">>, Map))).

%% maybe_pause_rescue: valid command produces rescue_paused_v1
handle_valid_pause_test() ->
    {ok, Cmd} = pause_rescue_v1:new(#{
        division_id => <<"div-1">>,
        reason => <<"Waiting for dependency">>
    }),
    {ok, [Event]} = maybe_pause_rescue:handle(Cmd),
    Map = rescue_paused_v1:to_map(Event),
    ?assertEqual(<<"rescue_paused_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"Waiting for dependency">>, maps:get(<<"reason">>, Map)).

%% maybe_resume_rescue: valid command produces rescue_resumed_v1
handle_valid_resume_test() ->
    {ok, Cmd} = resume_rescue_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_resume_rescue:handle(Cmd),
    Map = rescue_resumed_v1:to_map(Event),
    ?assertEqual(<<"rescue_resumed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assert(is_integer(maps:get(<<"resumed_at">>, Map))).

%% maybe_complete_rescue: valid command produces rescue_completed_v1
handle_valid_complete_test() ->
    {ok, Cmd} = complete_rescue_v1:new(#{
        division_id => <<"div-1">>
    }),
    {ok, [Event]} = maybe_complete_rescue:handle(Cmd),
    Map = rescue_completed_v1:to_map(Event),
    ?assertEqual(<<"rescue_completed_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assert(is_integer(maps:get(<<"completed_at">>, Map))).

%% maybe_archive_rescue: valid command produces rescue_archived_v1
handle_valid_archive_test() ->
    {ok, Cmd} = archive_rescue_v1:new(#{
        division_id => <<"div-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_rescue:handle(Cmd),
    Map = rescue_archived_v1:to_map(Event),
    ?assertEqual(<<"rescue_archived_v1">>, maps:get(<<"event_type">>, Map)),
    ?assertEqual(<<"div-1">>, maps:get(<<"division_id">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- start_rescue command ---

execute_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"start_rescue">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>},
    {ok, [EventMap]} = rescue_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"rescue_started_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_start_requires_incident_id_test() ->
    Cmd = #{<<"command_type">> => <<"start_rescue">>,
            <<"division_id">> => <<"div-1">>},
    %% Missing incident_id causes from_map -> validate -> {error, ...}
    %% which crashes with badmatch in execute_start_rescue/1
    ?assertError({badmatch, {error, {invalid_field, incident_id}}},
                 rescue_aggregate:execute(fresh_state(), Cmd)).

%% Non-start command on fresh state returns rescue_not_started
execute_non_start_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"pause_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, rescue_not_started},
                 rescue_aggregate:execute(fresh_state(), Cmd)).

%% --- diagnose_incident command ---

execute_diagnose_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"diagnose_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"diagnosis">> => <<"Root cause found">>,
            <<"root_cause">> => <<"Config error">>},
    {ok, [EventMap]} = rescue_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"incident_diagnosed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_diagnose_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"diagnose_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"diagnosis">> => <<"X">>,
            <<"root_cause">> => <<"Y">>},
    ?assertMatch({error, {not_active, _}},
                 rescue_aggregate:execute(paused_state(), Cmd)).

execute_diagnose_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"diagnose_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"diagnosis">> => <<"X">>,
            <<"root_cause">> => <<"Y">>},
    ?assertMatch({error, {not_active, _}},
                 rescue_aggregate:execute(completed_state(), Cmd)).

%% --- apply_fix command ---

execute_apply_fix_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"apply_fix">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"diagnosis_id">> => <<"diag-1">>,
            <<"fix_description">> => <<"Patched config">>,
            <<"fix_type">> => <<"patch">>},
    {ok, [EventMap]} = rescue_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"fix_applied_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_apply_fix_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"apply_fix">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"diagnosis_id">> => <<"diag-1">>,
            <<"fix_description">> => <<"X">>,
            <<"fix_type">> => <<"Y">>},
    ?assertMatch({error, {not_active, _}},
                 rescue_aggregate:execute(paused_state(), Cmd)).

%% --- pause_rescue command ---

execute_pause_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"pause_rescue">>,
            <<"division_id">> => <<"div-1">>,
            <<"reason">> => <<"Blocked">>},
    {ok, [EventMap]} = rescue_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"rescue_paused_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_pause_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"pause_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 rescue_aggregate:execute(paused_state(), Cmd)).

execute_pause_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"pause_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 rescue_aggregate:execute(completed_state(), Cmd)).

%% --- resume_rescue command ---

execute_resume_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"resume_rescue">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = rescue_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"rescue_resumed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_resume_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"resume_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_paused, _}},
                 rescue_aggregate:execute(started_state(), Cmd)).

execute_resume_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"resume_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_paused, _}},
                 rescue_aggregate:execute(completed_state(), Cmd)).

%% --- complete_rescue command ---

execute_complete_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"complete_rescue">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = rescue_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"rescue_completed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_complete_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"complete_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 rescue_aggregate:execute(paused_state(), Cmd)).

execute_complete_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"complete_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertMatch({error, {not_active, _}},
                 rescue_aggregate:execute(completed_state(), Cmd)).

%% --- archive_rescue command ---

execute_archive_on_active_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_rescue">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = rescue_aggregate:execute(started_state(), Cmd),
    ?assertEqual(<<"rescue_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_on_completed_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_rescue">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = rescue_aggregate:execute(completed_state(), Cmd),
    ?assertEqual(<<"rescue_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_rescue">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, rescue_archived},
                 rescue_aggregate:execute(archived_state(), Cmd)).

execute_archive_on_paused_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_rescue">>,
            <<"division_id">> => <<"div-1">>},
    {ok, [EventMap]} = rescue_aggregate:execute(paused_state(), Cmd),
    ?assertEqual(<<"rescue_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

%% --- unknown command ---

execute_unknown_command_on_active_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 rescue_aggregate:execute(started_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertEqual({error, rescue_not_started},
                 rescue_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"start_rescue">>,
                <<"division_id">> => <<"div-order">>,
                <<"incident_id">> => <<"inc-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = rescue_aggregate:execute(State, Payload).

%% --- lifecycle transitions after resume ---

execute_diagnose_after_resume_test() ->
    Resumed = rescue_aggregate:apply(paused_state(), resume_event_map()),
    Cmd = #{<<"command_type">> => <<"diagnose_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"diagnosis">> => <<"Found it">>,
            <<"root_cause">> => <<"Config">>},
    {ok, [EventMap]} = rescue_aggregate:execute(Resumed, Cmd),
    ?assertEqual(<<"incident_diagnosed_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_apply_fix_after_resume_test() ->
    Resumed = rescue_aggregate:apply(paused_state(), resume_event_map()),
    Cmd = #{<<"command_type">> => <<"apply_fix">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"diagnosis_id">> => <<"diag-1">>,
            <<"fix_description">> => <<"Fixed">>,
            <<"fix_type">> => <<"patch">>},
    {ok, [EventMap]} = rescue_aggregate:execute(Resumed, Cmd),
    ?assertEqual(<<"fix_applied_v1">>, maps:get(<<"event_type">>, EventMap)).
