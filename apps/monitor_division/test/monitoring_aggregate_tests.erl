%%% @doc Layer 1: Dossier Tests -- Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since monitoring_state record is internal to monitoring_aggregate,
%%% we verify state correctness through execute/2 behavior (state machine
%%% guards) and through the behaviour callback apply/2.
%%%
%%% This app has 8 commands/events -- the most of any lifecycle app.
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands (only when active): register_health_check,
%%%   record_health_status, raise_incident.
-module(monitoring_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("monitor_division/include/monitoring_status.hrl").

%% Record field positions in monitoring_state (record tag is element 1)
-define(F_DIVISION_ID,   2).
-define(F_STATUS,        3).
-define(F_HEALTH_CHECKS, 4).
-define(F_INCIDENTS,     5).
-define(F_STARTED_AT,    6).
-define(F_PAUSED_AT,     7).
-define(F_COMPLETED_AT,  8).
-define(F_PAUSE_REASON,  9).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"monitoring_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

health_check_registered_event() ->
    #{<<"event_type">> => <<"health_check_registered_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"check_id">> => <<"check-div-1-api">>,
      <<"check_name">> => <<"api">>,
      <<"check_type">> => <<"http">>,
      <<"endpoint">> => <<"https://api.example.com/health">>,
      <<"interval_ms">> => 30000,
      <<"registered_at">> => 1100}.

health_status_recorded_event() ->
    #{<<"event_type">> => <<"health_status_recorded_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"check_id">> => <<"check-div-1-api">>,
      <<"status">> => <<"healthy">>,
      <<"latency_ms">> => 42,
      <<"details">> => <<"200 OK">>,
      <<"recorded_at">> => 1200}.

incident_raised_event() ->
    #{<<"event_type">> => <<"incident_raised_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"incident_id">> => <<"inc-div-1-1300">>,
      <<"incident_title">> => <<"API Down">>,
      <<"severity">> => <<"high">>,
      <<"description">> => <<"Health check failed 3 times">>,
      <<"raised_at">> => 1300}.

pause_event() ->
    #{<<"event_type">> => <<"monitoring_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 2000,
      <<"reason">> => <<"maintenance window">>}.

resume_event() ->
    #{<<"event_type">> => <<"monitoring_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 2500}.

complete_event() ->
    #{<<"event_type">> => <<"monitoring_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 3000}.

archive_event() ->
    #{<<"event_type">> => <<"monitoring_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 4000,
      <<"archived_by">> => <<"test@host">>,
      <<"reason">> => <<"test cleanup">>}.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% init/1 callback returns {ok, state} with zeroed fields
init_callback_test() ->
    {ok, S} = monitoring_aggregate:init(<<"any-id">>),
    ?assertEqual(undefined, element(?F_DIVISION_ID, S)),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual(#{}, element(?F_HEALTH_CHECKS, S)),
    ?assertEqual(#{}, element(?F_INCIDENTS, S)),
    ?assertEqual(undefined, element(?F_STARTED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S)),
    ?assertEqual(undefined, element(?F_COMPLETED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S)).

%% Apply monitoring_started_v1 populates division_id, status, started_at
apply_start_event_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)),
    Status = element(?F_STATUS, S1),
    ?assertNotEqual(0, Status band ?MONITORING_INITIATED),
    ?assertNotEqual(0, Status band ?MONITORING_ACTIVE),
    ?assertEqual(1000, element(?F_STARTED_AT, S1)).

%% Apply health_check_registered_v1 adds to health_checks map
apply_health_check_registered_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, health_check_registered_event()),
    Checks = element(?F_HEALTH_CHECKS, S2),
    ?assert(maps:is_key(<<"check-div-1-api">>, Checks)),
    Check = maps:get(<<"check-div-1-api">>, Checks),
    ?assertEqual(<<"api">>, maps:get(check_name, Check)),
    ?assertEqual(<<"http">>, maps:get(check_type, Check)),
    ?assertEqual(<<"https://api.example.com/health">>, maps:get(endpoint, Check)),
    ?assertEqual(30000, maps:get(interval_ms, Check)),
    ?assertEqual(1100, maps:get(registered_at, Check)).

%% Registering a second health check adds to map without losing first
apply_multiple_health_checks_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, health_check_registered_event()),
    SecondCheck = #{<<"event_type">> => <<"health_check_registered_v1">>,
                    <<"division_id">> => <<"div-1">>,
                    <<"check_id">> => <<"check-div-1-db">>,
                    <<"check_name">> => <<"db">>,
                    <<"check_type">> => <<"tcp">>,
                    <<"endpoint">> => <<"db.internal:5432">>,
                    <<"interval_ms">> => 60000,
                    <<"registered_at">> => 1150},
    S3 = monitoring_aggregate:apply(S2, SecondCheck),
    Checks = element(?F_HEALTH_CHECKS, S3),
    ?assertEqual(2, maps:size(Checks)),
    ?assert(maps:is_key(<<"check-div-1-api">>, Checks)),
    ?assert(maps:is_key(<<"check-div-1-db">>, Checks)).

%% Apply health_status_recorded_v1 updates existing check with last_status
apply_health_status_recorded_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, health_check_registered_event()),
    S3 = monitoring_aggregate:apply(S2, health_status_recorded_event()),
    Checks = element(?F_HEALTH_CHECKS, S3),
    Check = maps:get(<<"check-div-1-api">>, Checks),
    ?assertEqual(<<"healthy">>, maps:get(last_status, Check)),
    ?assertEqual(42, maps:get(last_latency_ms, Check)),
    ?assertEqual(1200, maps:get(last_recorded_at, Check)).

%% Apply incident_raised_v1 adds to incidents map
apply_incident_raised_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, incident_raised_event()),
    Incidents = element(?F_INCIDENTS, S2),
    ?assert(maps:is_key(<<"inc-div-1-1300">>, Incidents)),
    Inc = maps:get(<<"inc-div-1-1300">>, Incidents),
    ?assertEqual(<<"API Down">>, maps:get(incident_title, Inc)),
    ?assertEqual(<<"high">>, maps:get(severity, Inc)),
    ?assertEqual(<<"Health check failed 3 times">>, maps:get(description, Inc)),
    ?assertEqual(1300, maps:get(raised_at, Inc)).

%% Apply pause event: unsets ACTIVE, sets PAUSED, records paused_at + reason
apply_pause_event_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, pause_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?MONITORING_INITIATED),
    ?assertEqual(0, Status band ?MONITORING_ACTIVE),
    ?assertNotEqual(0, Status band ?MONITORING_PAUSED),
    ?assertEqual(2000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"maintenance window">>, element(?F_PAUSE_REASON, S2)).

%% Apply resume event: unsets PAUSED, sets ACTIVE, clears paused_at + reason
apply_resume_event_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, pause_event()),
    S3 = monitoring_aggregate:apply(S2, resume_event()),
    Status = element(?F_STATUS, S3),
    ?assertNotEqual(0, Status band ?MONITORING_INITIATED),
    ?assertNotEqual(0, Status band ?MONITORING_ACTIVE),
    ?assertEqual(0, Status band ?MONITORING_PAUSED),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).

%% Apply complete event: unsets ACTIVE, sets COMPLETED, records completed_at
apply_complete_event_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, complete_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?MONITORING_INITIATED),
    ?assertEqual(0, Status band ?MONITORING_ACTIVE),
    ?assertNotEqual(0, Status band ?MONITORING_COMPLETED),
    ?assertEqual(3000, element(?F_COMPLETED_AT, S2)).

%% Apply archive event: sets ARCHIVED bit, preserves other status
apply_archive_event_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, archive_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?MONITORING_INITIATED),
    ?assertNotEqual(0, Status band ?MONITORING_ARCHIVED).

%% Full lifecycle: start -> pause -> resume -> complete -> archive
full_lifecycle_state_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, pause_event()),
    S3 = monitoring_aggregate:apply(S2, resume_event()),
    S4 = monitoring_aggregate:apply(S3, complete_event()),
    S5 = monitoring_aggregate:apply(S4, archive_event()),
    Status = element(?F_STATUS, S5),
    ?assertNotEqual(0, Status band ?MONITORING_INITIATED),
    ?assertNotEqual(0, Status band ?MONITORING_COMPLETED),
    ?assertNotEqual(0, Status band ?MONITORING_ARCHIVED),
    ?assertEqual(0, Status band ?MONITORING_ACTIVE),
    ?assertEqual(0, Status band ?MONITORING_PAUSED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S5)),
    ?assertEqual(3000, element(?F_COMPLETED_AT, S5)).

%% Domain events accumulate: health checks + incidents survive lifecycle
domain_events_survive_lifecycle_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, health_check_registered_event()),
    S3 = monitoring_aggregate:apply(S2, health_status_recorded_event()),
    S4 = monitoring_aggregate:apply(S3, incident_raised_event()),
    S5 = monitoring_aggregate:apply(S4, pause_event()),
    S6 = monitoring_aggregate:apply(S5, resume_event()),
    S7 = monitoring_aggregate:apply(S6, complete_event()),
    %% Health checks and incidents survive through lifecycle transitions
    ?assertEqual(1, maps:size(element(?F_HEALTH_CHECKS, S7))),
    ?assertEqual(1, maps:size(element(?F_INCIDENTS, S7))).

%% Unknown event leaves state unchanged
apply_unknown_event_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    Unknown = #{<<"event_type">> => <<"some_random_event">>, <<"data">> => <<"whatever">>},
    S2 = monitoring_aggregate:apply(S1, Unknown),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
apply_with_atom_keys_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    AtomEvent = #{event_type => <<"monitoring_started_v1">>,
                  division_id => <<"div-atom">>,
                  started_at => 5000,
                  started_by => <<"atom@host">>},
    S1 = monitoring_aggregate:apply(S0, AtomEvent),
    ?assertEqual(<<"div-atom">>, element(?F_DIVISION_ID, S1)),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?MONITORING_INITIATED).

%% Behaviour callback: apply(State, Event) -- state first
apply_callback_order_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?MONITORING_INITIATED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)).

%% ===================================================================
%% State Machine via execute/2
%% ===================================================================

%% Fresh state: start should succeed
state_machine_start_on_fresh_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    Cmd = #{<<"command_type">> => <<"start_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    {ok, _Events} = monitoring_aggregate:execute(S0, Cmd).

%% Fresh state: other commands should fail
state_machine_reject_non_start_on_fresh_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    PauseCmd = #{<<"command_type">> => <<"pause_monitoring">>,
                 <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, monitoring_not_started},
                 monitoring_aggregate:execute(S0, PauseCmd)).

%% After start: commands requiring active state should succeed
state_machine_active_allows_domain_commands_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    RegisterCmd = #{<<"command_type">> => <<"register_health_check">>,
                    <<"division_id">> => <<"div-1">>,
                    <<"check_name">> => <<"api">>},
    {ok, _Events} = monitoring_aggregate:execute(S1, RegisterCmd).

%% After archive: all commands should fail
state_machine_archived_rejects_all_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    S1 = monitoring_aggregate:apply(S0, start_event()),
    S2 = monitoring_aggregate:apply(S1, archive_event()),
    Cmd = #{<<"command_type">> => <<"pause_monitoring">>,
            <<"division_id">> => <<"div-1">>},
    ?assertEqual({error, monitoring_archived},
                 monitoring_aggregate:execute(S2, Cmd)).

%% Unknown command returns error
state_machine_unknown_command_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    ?assertEqual({error, monitoring_not_started},
                 monitoring_aggregate:execute(S0, #{<<"command_type">> => <<"bogus">>})).

%% Missing command_type returns error
state_machine_missing_command_type_test() ->
    {ok, S0} = monitoring_aggregate:init(<<"div-1">>),
    ?assertEqual({error, monitoring_not_started},
                 monitoring_aggregate:execute(S0, #{<<"data">> => <<"stuff">>})).
