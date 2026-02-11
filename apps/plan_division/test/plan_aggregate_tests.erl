%%% @doc Layer 1: Dossier Tests -- Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since plan_state record is internal to plan_aggregate, we verify
%%% state correctness through execute/2 behavior (state machine guards)
%%% and through the behaviour callback apply/2.
-module(plan_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("plan_division/include/plan_status.hrl").

%% Record field positions in plan_state (record tag is element 1)
-define(F_DIVISION_ID,          2).
-define(F_STATUS,               3).
-define(F_PLANNED_DESKS,        4).
-define(F_PLANNED_DEPENDENCIES, 5).
-define(F_STARTED_AT,           6).
-define(F_PAUSED_AT,            7).
-define(F_COMPLETED_AT,         8).
-define(F_PAUSE_REASON,         9).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"plan_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

plan_desk_event() ->
    #{<<"event_type">> => <<"desk_planned_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"desk_id">> => <<"desk-001">>,
      <<"desk_name">> => <<"register_user">>,
      <<"department">> => <<"CMD">>,
      <<"aggregate_name">> => <<"user_aggregate">>,
      <<"description">> => <<"Register a new user">>,
      <<"priority">> => 1,
      <<"planned_by">> => <<"test@host">>,
      <<"planned_at">> => 2000}.

plan_dependency_event() ->
    #{<<"event_type">> => <<"dependency_planned_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"dependency_id">> => <<"dep-001">>,
      <<"from_desk">> => <<"register_user">>,
      <<"to_desk">> => <<"send_welcome_email">>,
      <<"dependency_type">> => <<"triggers">>,
      <<"description">> => <<"Registration triggers welcome email">>,
      <<"planned_by">> => <<"test@host">>,
      <<"planned_at">> => 3000}.

pause_event() ->
    #{<<"event_type">> => <<"plan_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"needs review">>}.

resume_event() ->
    #{<<"event_type">> => <<"plan_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 5000}.

complete_event() ->
    #{<<"event_type">> => <<"plan_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event() ->
    #{<<"event_type">> => <<"plan_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin@host">>,
      <<"reason">> => <<"obsolete">>}.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% init/1 callback returns {ok, initial_state} with zeroed fields
initial_state_test() ->
    {ok, S} = plan_aggregate:init(<<"any-id">>),
    ?assertEqual(undefined, element(?F_DIVISION_ID, S)),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual(#{}, element(?F_PLANNED_DESKS, S)),
    ?assertEqual(#{}, element(?F_PLANNED_DEPENDENCIES, S)),
    ?assertEqual(undefined, element(?F_STARTED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S)),
    ?assertEqual(undefined, element(?F_COMPLETED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S)).

%% init/1 callback wraps state in {ok, _} tuple
init_callback_test() ->
    {ok, S} = plan_aggregate:init(<<"test">>),
    ?assertEqual(0, element(?F_STATUS, S)).

%% Apply plan_started_v1 sets division_id, INITIATED+ACTIVE flags, started_at
apply_start_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    Status = element(?F_STATUS, S1),
    ?assertNotEqual(0, Status band ?PLAN_INITIATED),
    ?assertNotEqual(0, Status band ?PLAN_ACTIVE),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(1000, element(?F_STARTED_AT, S1)).

%% Apply desk_planned_v1 adds desk to planned_desks map
apply_plan_desk_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, plan_desk_event()),
    Desks = element(?F_PLANNED_DESKS, S2),
    ?assert(maps:is_key(<<"register_user">>, Desks)),
    DeskDetails = maps:get(<<"register_user">>, Desks),
    ?assertEqual(<<"register_user">>, maps:get(desk_name, DeskDetails)),
    ?assertEqual(<<"CMD">>, maps:get(department, DeskDetails)),
    ?assertEqual(<<"Register a new user">>, maps:get(description, DeskDetails)).

%% Apply dependency_planned_v1 adds dependency to planned_dependencies map
apply_plan_dependency_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, plan_dependency_event()),
    Deps = element(?F_PLANNED_DEPENDENCIES, S2),
    ?assert(maps:is_key(<<"dep-001">>, Deps)),
    DepDetails = maps:get(<<"dep-001">>, Deps),
    ?assertEqual(<<"dep-001">>, maps:get(dependency_id, DepDetails)),
    ?assertEqual(<<"register_user">>, maps:get(from_desk, DepDetails)),
    ?assertEqual(<<"send_welcome_email">>, maps:get(to_desk, DepDetails)),
    ?assertEqual(<<"triggers">>, maps:get(dependency_type, DepDetails)).

%% Apply plan_paused_v1 clears ACTIVE, sets PAUSED, records paused_at and reason
apply_pause_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, pause_event()),
    Status = element(?F_STATUS, S2),
    ?assertEqual(0, Status band ?PLAN_ACTIVE),
    ?assertNotEqual(0, Status band ?PLAN_PAUSED),
    ?assertEqual(4000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"needs review">>, element(?F_PAUSE_REASON, S2)).

%% Apply plan_resumed_v1 clears PAUSED, sets ACTIVE, clears paused_at and reason
apply_resume_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, pause_event()),
    S3 = plan_aggregate:apply(S2, resume_event()),
    Status = element(?F_STATUS, S3),
    ?assertNotEqual(0, Status band ?PLAN_ACTIVE),
    ?assertEqual(0, Status band ?PLAN_PAUSED),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).

%% Apply plan_completed_v1 clears ACTIVE, sets COMPLETED, records completed_at
apply_complete_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, complete_event()),
    Status = element(?F_STATUS, S2),
    ?assertEqual(0, Status band ?PLAN_ACTIVE),
    ?assertNotEqual(0, Status band ?PLAN_COMPLETED),
    ?assertEqual(6000, element(?F_COMPLETED_AT, S2)).

%% Apply plan_archived_v1 sets ARCHIVED flag
apply_archive_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, archive_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?PLAN_ARCHIVED),
    ?assertNotEqual(0, Status band ?PLAN_INITIATED).

%% Full lifecycle: start -> desk -> dependency -> pause -> resume -> complete -> archive
full_lifecycle_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, plan_desk_event()),
    S3 = plan_aggregate:apply(S2, plan_dependency_event()),
    S4 = plan_aggregate:apply(S3, pause_event()),
    S5 = plan_aggregate:apply(S4, resume_event()),
    S6 = plan_aggregate:apply(S5, complete_event()),
    S7 = plan_aggregate:apply(S6, archive_event()),
    Status = element(?F_STATUS, S7),
    ?assertNotEqual(0, Status band ?PLAN_INITIATED),
    ?assertNotEqual(0, Status band ?PLAN_COMPLETED),
    ?assertNotEqual(0, Status band ?PLAN_ARCHIVED),
    ?assertEqual(0, Status band ?PLAN_ACTIVE),
    ?assertEqual(0, Status band ?PLAN_PAUSED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S7)),
    ?assertEqual(1, maps:size(element(?F_PLANNED_DESKS, S7))),
    ?assertEqual(1, maps:size(element(?F_PLANNED_DEPENDENCIES, S7))).

%% Unknown event leaves state unchanged
unknown_event_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    Unknown = #{<<"event_type">> => <<"some_random_event">>, <<"data">> => <<"whatever">>},
    S2 = plan_aggregate:apply(S1, Unknown),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
atom_keys_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    AtomEvent = #{event_type => <<"plan_started_v1">>,
                  division_id => <<"div-atom">>,
                  started_at => 9000,
                  started_by => <<"atom@host">>},
    S1 = plan_aggregate:apply(S0, AtomEvent),
    ?assertEqual(<<"div-atom">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(9000, element(?F_STARTED_AT, S1)),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?PLAN_INITIATED).

%% Flag map macro contains expected labels
flag_map_test() ->
    Map = ?PLAN_FLAG_MAP,
    ?assertEqual(<<"Initiated">>, maps:get(?PLAN_INITIATED, Map)),
    ?assertEqual(<<"Active">>, maps:get(?PLAN_ACTIVE, Map)),
    ?assertEqual(<<"Paused">>, maps:get(?PLAN_PAUSED, Map)),
    ?assertEqual(<<"Completed">>, maps:get(?PLAN_COMPLETED, Map)),
    ?assertEqual(<<"Archived">>, maps:get(?PLAN_ARCHIVED, Map)).

%% Behaviour callback: apply/2 takes (State, Event) -- state first
callback_order_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?PLAN_INITIATED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)).

%% Multiple desks accumulate in planned_desks map
multiple_desks_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, plan_desk_event()),
    SecondDesk = #{<<"event_type">> => <<"desk_planned_v1">>,
                   <<"division_id">> => <<"div-1">>,
                   <<"desk_id">> => <<"desk-002">>,
                   <<"desk_name">> => <<"promote_user">>,
                   <<"department">> => <<"CMD">>,
                   <<"description">> => <<"Promote a user">>,
                   <<"priority">> => 2,
                   <<"planned_at">> => 2500},
    S3 = plan_aggregate:apply(S2, SecondDesk),
    Desks = element(?F_PLANNED_DESKS, S3),
    ?assertEqual(2, maps:size(Desks)),
    ?assert(maps:is_key(<<"register_user">>, Desks)),
    ?assert(maps:is_key(<<"promote_user">>, Desks)).

%% Multiple dependencies accumulate in planned_dependencies map
multiple_dependencies_test() ->
    {ok, S0} = plan_aggregate:init(<<"x">>),
    S1 = plan_aggregate:apply(S0, start_event()),
    S2 = plan_aggregate:apply(S1, plan_dependency_event()),
    SecondDep = #{<<"event_type">> => <<"dependency_planned_v1">>,
                  <<"division_id">> => <<"div-1">>,
                  <<"dependency_id">> => <<"dep-002">>,
                  <<"from_desk">> => <<"promote_user">>,
                  <<"to_desk">> => <<"notify_admin">>,
                  <<"dependency_type">> => <<"notifies">>,
                  <<"planned_at">> => 3500},
    S3 = plan_aggregate:apply(S2, SecondDep),
    Deps = element(?F_PLANNED_DEPENDENCIES, S3),
    ?assertEqual(2, maps:size(Deps)),
    ?assert(maps:is_key(<<"dep-001">>, Deps)),
    ?assert(maps:is_key(<<"dep-002">>, Deps)).
