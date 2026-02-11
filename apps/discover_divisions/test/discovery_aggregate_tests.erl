%%% @doc Layer 1: Dossier Tests -- Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since discovery_state record is internal to discovery_aggregate,
%%% we verify state correctness through element/2 positional access
%%% and through the behaviour callbacks apply/2 and execute/2.
-module(discovery_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("discover_divisions/include/discovery_status.hrl").

%% Record field positions in discovery_state (record tag is element 1)
-define(F_VENTURE_ID, 2).
-define(F_STATUS, 3).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"discovery_started_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

discover_event() ->
    #{<<"event_type">> => <<"division_discovered_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"division_id">> => <<"div-1">>,
      <<"context_name">> => <<"auth">>,
      <<"description">> => <<"Auth context">>,
      <<"identified_by">> => <<"user@host">>,
      <<"discovered_at">> => 2000}.

pause_event() ->
    #{<<"event_type">> => <<"discovery_paused_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"paused_at">> => 3000,
      <<"reason">> => <<"review">>}.

resume_event() ->
    #{<<"event_type">> => <<"discovery_resumed_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"resumed_at">> => 4000}.

complete_event() ->
    #{<<"event_type">> => <<"discovery_completed_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"completed_at">> => 5000}.

archive_event() ->
    #{<<"event_type">> => <<"discovery_archived_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"archived_at">> => 6000,
      <<"archived_by">> => <<"admin">>,
      <<"reason">> => <<"done">>}.

fresh_state() ->
    {ok, S} = discovery_aggregate:init(<<"any-id">>),
    S.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% init/1 callback returns {ok, state} with zeroed status
init_callback_test() ->
    {ok, S} = discovery_aggregate:init(<<"any-id">>),
    ?assertEqual(0, element(?F_STATUS, S)).

%% Apply discovery_started_v1 sets INITIATED + ACTIVE flags and venture_id
apply_start_event_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DISCOVERY_INITIATED),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DISCOVERY_ACTIVE),
    ?assertEqual(<<"vent-1">>, element(?F_VENTURE_ID, S1)).

%% Apply division_discovered_v1 preserves INITIATED + ACTIVE (adds division)
apply_discover_event_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    S2 = discovery_aggregate:apply(S1, discover_event()),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?DISCOVERY_INITIATED),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?DISCOVERY_ACTIVE).

%% Apply discovery_paused_v1 sets PAUSED and clears ACTIVE
apply_pause_event_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    S2 = discovery_aggregate:apply(S1, pause_event()),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?DISCOVERY_PAUSED),
    ?assertEqual(0, element(?F_STATUS, S2) band ?DISCOVERY_ACTIVE).

%% Apply discovery_resumed_v1 restores ACTIVE and clears PAUSED
apply_resume_event_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    S2 = discovery_aggregate:apply(S1, pause_event()),
    S3 = discovery_aggregate:apply(S2, resume_event()),
    ?assertNotEqual(0, element(?F_STATUS, S3) band ?DISCOVERY_ACTIVE),
    ?assertEqual(0, element(?F_STATUS, S3) band ?DISCOVERY_PAUSED).

%% Apply discovery_completed_v1 sets COMPLETED and clears ACTIVE
apply_complete_event_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    S2 = discovery_aggregate:apply(S1, complete_event()),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?DISCOVERY_COMPLETED),
    ?assertEqual(0, element(?F_STATUS, S2) band ?DISCOVERY_ACTIVE).

%% Apply discovery_archived_v1 sets ARCHIVED
apply_archive_event_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    S2 = discovery_aggregate:apply(S1, archive_event()),
    ?assertNotEqual(0, element(?F_STATUS, S2) band ?DISCOVERY_ARCHIVED).

%% Full lifecycle: start -> discover -> pause -> resume -> complete -> archive
full_lifecycle_state_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    S2 = discovery_aggregate:apply(S1, discover_event()),
    S3 = discovery_aggregate:apply(S2, pause_event()),
    S4 = discovery_aggregate:apply(S3, resume_event()),
    S5 = discovery_aggregate:apply(S4, complete_event()),
    S6 = discovery_aggregate:apply(S5, archive_event()),
    FinalStatus = element(?F_STATUS, S6),
    ?assertNotEqual(0, FinalStatus band ?DISCOVERY_INITIATED),
    ?assertNotEqual(0, FinalStatus band ?DISCOVERY_COMPLETED),
    ?assertNotEqual(0, FinalStatus band ?DISCOVERY_ARCHIVED),
    %% ACTIVE should be cleared (completed clears it)
    ?assertEqual(0, FinalStatus band ?DISCOVERY_ACTIVE).

%% Unknown event leaves state unchanged
apply_unknown_event_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    S2 = discovery_aggregate:apply(S1, #{<<"event_type">> => <<"unknown">>}),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
apply_with_atom_keys_test() ->
    S0 = fresh_state(),
    AtomEvent = #{event_type => <<"discovery_started_v1">>,
                  venture_id => <<"vent-1">>,
                  started_at => 1000,
                  started_by => <<"test@host">>},
    S1 = discovery_aggregate:apply(S0, AtomEvent),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DISCOVERY_INITIATED),
    ?assertEqual(<<"vent-1">>, element(?F_VENTURE_ID, S1)).

%% Behaviour callback: apply/2 takes (State, Event) -- state first
apply_callback_order_test() ->
    S0 = fresh_state(),
    S1 = discovery_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DISCOVERY_INITIATED).
