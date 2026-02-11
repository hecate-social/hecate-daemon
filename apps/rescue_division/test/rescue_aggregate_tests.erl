%%% @doc Layer 1: Dossier Tests -- Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since rescue_state record is internal to rescue_aggregate,
%%% we verify state correctness through element/2 positional access
%%% and through the behaviour callbacks apply/2 and execute/2.
%%%
%%% rescue_state fields:
%%%   1=record_tag, 2=division_id, 3=incident_id, 4=status,
%%%   5=diagnoses, 6=fixes, 7=started_at, 8=paused_at,
%%%   9=completed_at, 10=pause_reason
-module(rescue_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("rescue_division/include/rescue_status.hrl").

%% Record field positions in rescue_state (record tag is element 1)
-define(F_DIVISION_ID, 2).
-define(F_INCIDENT_ID, 3).
-define(F_STATUS, 4).
-define(F_DIAGNOSES, 5).
-define(F_FIXES, 6).
-define(F_STARTED_AT, 7).
-define(F_PAUSED_AT, 8).
-define(F_COMPLETED_AT, 9).
-define(F_PAUSE_REASON, 10).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"rescue_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"incident_id">> => <<"inc-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

incident_diagnosed_event() ->
    #{<<"event_type">> => <<"incident_diagnosed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"incident_id">> => <<"inc-1">>,
      <<"diagnosis_id">> => <<"diag-1">>,
      <<"diagnosis">> => <<"Memory leak in worker pool">>,
      <<"root_cause">> => <<"Unbounded message queue growth">>,
      <<"diagnosed_by">> => <<"engineer@host">>,
      <<"diagnosed_at">> => 2000}.

fix_applied_event() ->
    #{<<"event_type">> => <<"fix_applied_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"incident_id">> => <<"inc-1">>,
      <<"diagnosis_id">> => <<"diag-1">>,
      <<"fix_id">> => <<"fix-1">>,
      <<"fix_description">> => <<"Added backpressure to worker pool">>,
      <<"fix_type">> => <<"hotfix">>,
      <<"applied_by">> => <<"engineer@host">>,
      <<"applied_at">> => 3000}.

pause_event() ->
    #{<<"event_type">> => <<"rescue_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"Awaiting upstream dependency">>}.

resume_event() ->
    #{<<"event_type">> => <<"rescue_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 5000}.

complete_event() ->
    #{<<"event_type">> => <<"rescue_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event() ->
    #{<<"event_type">> => <<"rescue_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"Incident resolved">>}.

fresh_state() ->
    {ok, S} = rescue_aggregate:init(<<"any-id">>),
    S.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% init/1 callback returns {ok, state} with zeroed status
init_callback_test() ->
    {ok, S} = rescue_aggregate:init(<<"any-id">>),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual(undefined, element(?F_DIVISION_ID, S)),
    ?assertEqual(undefined, element(?F_INCIDENT_ID, S)),
    ?assertEqual(#{}, element(?F_DIAGNOSES, S)),
    ?assertEqual(#{}, element(?F_FIXES, S)),
    ?assertEqual(undefined, element(?F_STARTED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S)),
    ?assertEqual(undefined, element(?F_COMPLETED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S)).

%% Apply rescue_started_v1 sets INITIATED + ACTIVE flags, division_id, incident_id
apply_start_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?RESCUE_INITIATED),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?RESCUE_ACTIVE),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(<<"inc-1">>, element(?F_INCIDENT_ID, S1)),
    ?assertEqual(1000, element(?F_STARTED_AT, S1)).

%% Apply incident_diagnosed_v1 adds diagnosis to diagnoses map
apply_diagnose_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, incident_diagnosed_event()),
    Diagnoses = element(?F_DIAGNOSES, S2),
    ?assert(maps:is_key(<<"diag-1">>, Diagnoses)),
    DiagDetail = maps:get(<<"diag-1">>, Diagnoses),
    ?assertEqual(<<"diag-1">>, maps:get(diagnosis_id, DiagDetail)),
    ?assertEqual(<<"Memory leak in worker pool">>, maps:get(diagnosis, DiagDetail)),
    ?assertEqual(<<"Unbounded message queue growth">>, maps:get(root_cause, DiagDetail)),
    %% Status unchanged (still INITIATED + ACTIVE)
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?RESCUE_ACTIVE).

%% Apply fix_applied_v1 adds fix to fixes map
apply_fix_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, fix_applied_event()),
    Fixes = element(?F_FIXES, S2),
    ?assert(maps:is_key(<<"fix-1">>, Fixes)),
    FixDetail = maps:get(<<"fix-1">>, Fixes),
    ?assertEqual(<<"fix-1">>, maps:get(fix_id, FixDetail)),
    ?assertEqual(<<"Added backpressure to worker pool">>, maps:get(fix_description, FixDetail)),
    ?assertEqual(<<"hotfix">>, maps:get(fix_type, FixDetail)),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?RESCUE_ACTIVE).

%% Multiple diagnoses accumulate in the map
apply_multiple_diagnoses_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, incident_diagnosed_event()),
    Diag2 = (incident_diagnosed_event())#{<<"diagnosis_id">> => <<"diag-2">>,
                                           <<"diagnosis">> => <<"CPU spike">>},
    S3 = rescue_aggregate:apply(S2, Diag2),
    Diagnoses = element(?F_DIAGNOSES, S3),
    ?assertEqual(2, maps:size(Diagnoses)),
    ?assert(maps:is_key(<<"diag-1">>, Diagnoses)),
    ?assert(maps:is_key(<<"diag-2">>, Diagnoses)).

%% Multiple fixes accumulate in the map
apply_multiple_fixes_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, fix_applied_event()),
    Fix2 = (fix_applied_event())#{<<"fix_id">> => <<"fix-2">>,
                                   <<"fix_description">> => <<"Increased timeout">>},
    S3 = rescue_aggregate:apply(S2, Fix2),
    Fixes = element(?F_FIXES, S3),
    ?assertEqual(2, maps:size(Fixes)),
    ?assert(maps:is_key(<<"fix-1">>, Fixes)),
    ?assert(maps:is_key(<<"fix-2">>, Fixes)).

%% Apply rescue_paused_v1 sets PAUSED and clears ACTIVE
apply_pause_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, pause_event()),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?RESCUE_PAUSED),
    ?assertEqual(0, element(?F_STATUS, S2) band ?RESCUE_ACTIVE),
    ?assertEqual(4000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"Awaiting upstream dependency">>, element(?F_PAUSE_REASON, S2)).

%% Apply rescue_resumed_v1 restores ACTIVE and clears PAUSED
apply_resume_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, pause_event()),
    S3 = rescue_aggregate:apply(S2, resume_event()),
    ?assertNotEqual(0, element(?F_STATUS, S3) band ?RESCUE_ACTIVE),
    ?assertEqual(0, element(?F_STATUS, S3) band ?RESCUE_PAUSED),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).

%% Apply rescue_completed_v1 sets COMPLETED and clears ACTIVE
apply_complete_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, complete_event()),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?RESCUE_COMPLETED),
    ?assertEqual(0, element(?F_STATUS, S2) band ?RESCUE_ACTIVE),
    ?assertEqual(6000, element(?F_COMPLETED_AT, S2)).

%% Apply rescue_archived_v1 sets ARCHIVED
apply_archive_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, archive_event()),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?RESCUE_ARCHIVED).

%% Full lifecycle: start -> diagnose -> fix -> pause -> resume -> complete -> archive
full_lifecycle_state_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, incident_diagnosed_event()),
    S3 = rescue_aggregate:apply(S2, fix_applied_event()),
    S4 = rescue_aggregate:apply(S3, pause_event()),
    S5 = rescue_aggregate:apply(S4, resume_event()),
    S6 = rescue_aggregate:apply(S5, complete_event()),
    S7 = rescue_aggregate:apply(S6, archive_event()),
    FinalStatus = element(?F_STATUS, S7),
    ?assertNotEqual(0, FinalStatus band ?RESCUE_INITIATED),
    ?assertNotEqual(0, FinalStatus band ?RESCUE_COMPLETED),
    ?assertNotEqual(0, FinalStatus band ?RESCUE_ARCHIVED),
    %% ACTIVE should be cleared (completed clears it)
    ?assertEqual(0, FinalStatus band ?RESCUE_ACTIVE),
    %% Diagnoses and fixes accumulated
    ?assertEqual(1, maps:size(element(?F_DIAGNOSES, S7))),
    ?assertEqual(1, maps:size(element(?F_FIXES, S7))),
    %% Identity fields preserved
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S7)),
    ?assertEqual(<<"inc-1">>, element(?F_INCIDENT_ID, S7)).

%% Unknown event leaves state unchanged
apply_unknown_event_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    S2 = rescue_aggregate:apply(S1, #{<<"event_type">> => <<"unknown">>}),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
apply_with_atom_keys_test() ->
    S0 = fresh_state(),
    AtomEvent = #{event_type => <<"rescue_started_v1">>,
                  division_id => <<"div-atom">>,
                  incident_id => <<"inc-atom">>,
                  started_at => 9000,
                  started_by => <<"test@host">>},
    S1 = rescue_aggregate:apply(S0, AtomEvent),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?RESCUE_INITIATED),
    ?assertEqual(<<"div-atom">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(<<"inc-atom">>, element(?F_INCIDENT_ID, S1)).

%% Behaviour callback: apply/2 takes (State, Event) -- state first
apply_callback_order_test() ->
    S0 = fresh_state(),
    S1 = rescue_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?RESCUE_INITIATED).
