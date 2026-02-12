%%% @doc Tests for division_aggregate execute/2 and apply_event/2.
%%%
%%% Covers all 21 command types, phase gate pattern, and state transitions.
%%% Pure function tests — no external deps.
-module(division_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_division_alc/include/division_alc_status.hrl").

%% Copied from division_aggregate.erl for test-side record access.
-record(division_state, {
    division_id, venture_id, context_name,
    overall_status = 0,
    dna_status = 0, anp_status = 0, tni_status = 0, dno_status = 0,
    dna_started_at, dna_paused_at, dna_completed_at, dna_pause_reason,
    anp_started_at, anp_paused_at, anp_completed_at, anp_pause_reason,
    tni_started_at, tni_paused_at, tni_completed_at, tni_pause_reason,
    dno_started_at, dno_paused_at, dno_completed_at, dno_pause_reason,
    designed_aggregates = #{}, designed_events = #{},
    planned_desks = #{}, planned_dependencies = #{},
    generated_modules = #{}, generated_tests = #{},
    test_suites = #{}, test_results = #{},
    releases = #{}, rollout_stages = #{},
    health_checks = #{}, incidents = #{}, diagnoses = #{}, fixes = #{},
    initiated_at, initiated_by
}).

%% ===================================================================
%% Test generators
%% ===================================================================

aggregate_test_() ->
    [
        %% State guards
        {"fresh: only initiate allowed",               fun fresh_only_initiate/0},
        {"fresh: other commands rejected",             fun fresh_rejects_other/0},
        {"archived: all commands rejected",            fun archived_rejects_all/0},
        {"unknown command rejected",                   fun unknown_command_rejected/0},

        %% Phase lifecycle
        {"start_phase: dna phase starts",              fun start_phase_dna/0},
        {"start_phase: already started rejected",      fun start_phase_already_started/0},
        {"start_phase: invalid phase rejected",        fun start_phase_invalid/0},
        {"pause_phase: active phase pauses",           fun pause_phase_active/0},
        {"pause_phase: inactive rejected",             fun pause_phase_not_active/0},
        {"resume_phase: paused phase resumes",         fun resume_phase_paused/0},
        {"resume_phase: not paused rejected",          fun resume_phase_not_paused/0},
        {"complete_phase: active phase completes",     fun complete_phase_active/0},
        {"complete_phase: inactive rejected",          fun complete_phase_not_active/0},
        {"archive_division: succeeds",                 fun archive_division/0},

        %% Phase gate: domain commands require phase active
        {"phase gate: dna command requires dna active",  fun phase_gate_dna/0},
        {"phase gate: anp command requires anp active",  fun phase_gate_anp/0},
        {"phase gate: tni command requires tni active",  fun phase_gate_tni/0},
        {"phase gate: dno command requires dno active",  fun phase_gate_dno/0},

        %% DnA domain commands (via execute)
        {"design_aggregate: succeeds when dna active",   fun exec_design_aggregate/0},
        {"design_event: succeeds when dna active",       fun exec_design_event/0},

        %% AnP domain commands
        {"plan_desk: succeeds when anp active",          fun exec_plan_desk/0},
        {"plan_dependency: succeeds when anp active",    fun exec_plan_dependency/0},

        %% TnI domain commands
        {"generate_module: succeeds when tni active",    fun exec_generate_module/0},
        {"generate_test: succeeds when tni active",      fun exec_generate_test/0},
        {"run_test_suite: succeeds when tni active",     fun exec_run_test_suite/0},
        {"record_test_result: succeeds when tni active", fun exec_record_test_result/0},

        %% DnO domain commands
        {"deploy_release: succeeds when dno active",     fun exec_deploy_release/0},
        {"stage_rollout: succeeds when dno active",      fun exec_stage_rollout/0},
        {"register_health_check: succeeds when dno active", fun exec_register_health_check/0},
        {"record_health_status: succeeds when dno active",  fun exec_record_health_status/0},
        {"raise_incident: succeeds when dno active",     fun exec_raise_incident/0},
        {"diagnose_incident: succeeds when dno active",  fun exec_diagnose_incident/0},
        {"apply_fix: succeeds when dno active",          fun exec_apply_fix/0},

        %% Apply event tests
        {"apply: division_initiated sets fields",        fun apply_initiated/0},
        {"apply: division_archived sets flag",           fun apply_archived/0},
        {"apply: phase_started sets active",             fun apply_phase_started/0},
        {"apply: phase_paused unsets active sets paused", fun apply_phase_paused/0},
        {"apply: phase_resumed unsets paused sets active", fun apply_phase_resumed/0},
        {"apply: phase_completed sets completed",        fun apply_phase_completed/0},
        {"apply: aggregate_designed adds to map",        fun apply_aggregate_designed/0},
        {"apply: event_designed adds to map",            fun apply_event_designed/0},
        {"apply: desk_planned adds to map",              fun apply_desk_planned/0},
        {"apply: dependency_planned adds to map",        fun apply_dependency_planned/0},
        {"apply: module_generated adds to map",          fun apply_module_generated/0},
        {"apply: test_generated adds to map",            fun apply_test_generated/0},
        {"apply: test_suite_run adds to map",            fun apply_test_suite_run/0},
        {"apply: test_result_recorded adds to map",      fun apply_test_result_recorded/0},
        {"apply: release_deployed adds to map",          fun apply_release_deployed/0},
        {"apply: rollout_staged adds to map",            fun apply_rollout_staged/0},
        {"apply: health_check_registered adds to map",   fun apply_health_check_registered/0},
        {"apply: health_status_recorded updates existing", fun apply_health_status_recorded/0},
        {"apply: incident_raised adds to map",           fun apply_incident_raised/0},
        {"apply: incident_diagnosed adds to map",        fun apply_incident_diagnosed/0},
        {"apply: fix_applied adds to map",               fun apply_fix_applied/0},
        {"apply: unknown event leaves state unchanged",  fun apply_unknown_event/0},

        %% Integration: full lifecycle
        {"lifecycle: initiate -> dna -> anp -> tni -> dno -> archive", fun full_lifecycle/0}
    ].

%% ===================================================================
%% Helpers
%% ===================================================================

fresh() -> division_aggregate:initial_state().

initiated() ->
    Evt = #{<<"event_type">> => <<"division_initiated_v1">>,
            <<"division_id">> => <<"div-1">>, <<"venture_id">> => <<"v-1">>,
            <<"context_name">> => <<"auth">>,
            <<"initiated_at">> => 1000, <<"initiated_by">> => <<"user@test">>},
    division_aggregate:apply_event(Evt, fresh()).

%% State with division initiated and a specific phase started
with_phase(Phase) ->
    S0 = initiated(),
    Evt = #{<<"event_type">> => <<"phase_started_v1">>,
            <<"division_id">> => <<"div-1">>,
            <<"phase">> => atom_to_binary(Phase),
            <<"started_at">> => 2000},
    division_aggregate:apply_event(Evt, S0).

with_phase_paused(Phase) ->
    S0 = with_phase(Phase),
    Evt = #{<<"event_type">> => <<"phase_paused_v1">>,
            <<"division_id">> => <<"div-1">>,
            <<"phase">> => atom_to_binary(Phase),
            <<"paused_at">> => 3000, <<"reason">> => <<"blocked">>},
    division_aggregate:apply_event(Evt, S0).

initiate_cmd() ->
    #{<<"command_type">> => <<"initiate_division">>,
      <<"venture_id">> => <<"v-1">>,
      <<"context_name">> => <<"auth">>,
      <<"initiated_by">> => <<"user@test">>}.

%% ===================================================================
%% State guard tests
%% ===================================================================

fresh_only_initiate() ->
    {ok, [_Evt]} = division_aggregate:execute(fresh(), initiate_cmd()).

fresh_rejects_other() ->
    Cmd = #{<<"command_type">> => <<"start_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    ?assertEqual({error, division_not_initiated},
                 division_aggregate:execute(fresh(), Cmd)).

archived_rejects_all() ->
    S0 = initiated(),
    S1 = division_aggregate:apply_event(
        #{<<"event_type">> => <<"division_archived_v1">>,
          <<"division_id">> => <<"div-1">>}, S0),
    Cmd = #{<<"command_type">> => <<"start_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    ?assertEqual({error, division_archived},
                 division_aggregate:execute(S1, Cmd)).

unknown_command_rejected() ->
    ?assertEqual({error, unknown_command},
                 division_aggregate:execute(initiated(),
                     #{<<"command_type">> => <<"bogus">>})).

%% ===================================================================
%% Phase lifecycle tests
%% ===================================================================

start_phase_dna() ->
    Cmd = #{<<"command_type">> => <<"start_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    {ok, [Evt]} = division_aggregate:execute(initiated(), Cmd),
    ?assertEqual(<<"phase_started_v1">>, maps:get(<<"event_type">>, Evt)),
    ?assertEqual(<<"dna">>, maps:get(<<"phase">>, Evt)).

start_phase_already_started() ->
    Cmd = #{<<"command_type">> => <<"start_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    ?assertEqual({error, {phase_already_started, dna}},
                 division_aggregate:execute(with_phase(dna), Cmd)).

start_phase_invalid() ->
    Cmd = #{<<"command_type">> => <<"start_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"bogus">>},
    ?assertEqual({error, invalid_phase},
                 division_aggregate:execute(initiated(), Cmd)).

pause_phase_active() ->
    Cmd = #{<<"command_type">> => <<"pause_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>,
            <<"reason">> => <<"need more info">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dna), Cmd),
    ?assertEqual(<<"phase_paused_v1">>, maps:get(<<"event_type">>, Evt)).

pause_phase_not_active() ->
    Cmd = #{<<"command_type">> => <<"pause_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    ?assertEqual({error, {phase_not_active, dna}},
                 division_aggregate:execute(initiated(), Cmd)).

resume_phase_paused() ->
    Cmd = #{<<"command_type">> => <<"resume_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase_paused(dna), Cmd),
    ?assertEqual(<<"phase_resumed_v1">>, maps:get(<<"event_type">>, Evt)).

resume_phase_not_paused() ->
    Cmd = #{<<"command_type">> => <<"resume_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    ?assertEqual({error, {phase_not_paused, dna}},
                 division_aggregate:execute(with_phase(dna), Cmd)).

complete_phase_active() ->
    Cmd = #{<<"command_type">> => <<"complete_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dna), Cmd),
    ?assertEqual(<<"phase_completed_v1">>, maps:get(<<"event_type">>, Evt)).

complete_phase_not_active() ->
    Cmd = #{<<"command_type">> => <<"complete_phase">>,
            <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>},
    ?assertEqual({error, {phase_not_active, dna}},
                 division_aggregate:execute(initiated(), Cmd)).

archive_division() ->
    Cmd = #{<<"command_type">> => <<"archive_division">>,
            <<"division_id">> => <<"div-1">>, <<"reason">> => <<"obsolete">>},
    {ok, [Evt]} = division_aggregate:execute(initiated(), Cmd),
    ?assertEqual(<<"division_archived_v1">>, maps:get(<<"event_type">>, Evt)).

%% ===================================================================
%% Phase gate tests
%% ===================================================================

phase_gate_dna() ->
    Cmd = #{<<"command_type">> => <<"design_aggregate">>,
            <<"division_id">> => <<"div-1">>,
            <<"aggregate_name">> => <<"order">>,
            <<"description">> => <<"Order aggregate">>},
    %% Without dna active — rejected
    ?assertEqual({error, {phase_not_active, dna}},
                 division_aggregate:execute(initiated(), Cmd)),
    %% With dna active — succeeds
    {ok, [_]} = division_aggregate:execute(with_phase(dna), Cmd).

phase_gate_anp() ->
    Cmd = #{<<"command_type">> => <<"plan_desk">>,
            <<"division_id">> => <<"div-1">>,
            <<"desk_name">> => <<"place_order">>,
            <<"description">> => <<"Place order desk">>},
    ?assertEqual({error, {phase_not_active, anp}},
                 division_aggregate:execute(initiated(), Cmd)),
    {ok, [_]} = division_aggregate:execute(with_phase(anp), Cmd).

phase_gate_tni() ->
    Cmd = #{<<"command_type">> => <<"generate_module">>,
            <<"division_id">> => <<"div-1">>,
            <<"module_name">> => <<"place_order_v1">>,
            <<"module_type">> => <<"command">>},
    ?assertEqual({error, {phase_not_active, tni}},
                 division_aggregate:execute(initiated(), Cmd)),
    {ok, [_]} = division_aggregate:execute(with_phase(tni), Cmd).

phase_gate_dno() ->
    Cmd = #{<<"command_type">> => <<"deploy_release">>,
            <<"division_id">> => <<"div-1">>,
            <<"release_id">> => <<"rel-1">>,
            <<"version">> => <<"0.1.0">>},
    ?assertEqual({error, {phase_not_active, dno}},
                 division_aggregate:execute(initiated(), Cmd)),
    {ok, [_]} = division_aggregate:execute(with_phase(dno), Cmd).

%% ===================================================================
%% Domain command execute tests
%% ===================================================================

exec_design_aggregate() ->
    Cmd = #{<<"command_type">> => <<"design_aggregate">>,
            <<"division_id">> => <<"div-1">>,
            <<"aggregate_name">> => <<"order">>,
            <<"description">> => <<"Order aggregate">>,
            <<"stream_prefix">> => <<"order-">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dna), Cmd),
    ?assertEqual(<<"aggregate_designed_v1">>, maps:get(<<"event_type">>, Evt)),
    ?assertEqual(<<"order">>, maps:get(<<"aggregate_name">>, Evt)).

exec_design_event() ->
    Cmd = #{<<"command_type">> => <<"design_event">>,
            <<"division_id">> => <<"div-1">>,
            <<"event_name">> => <<"order_placed_v1">>,
            <<"description">> => <<"Order placed event">>,
            <<"aggregate_name">> => <<"order">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dna), Cmd),
    ?assertEqual(<<"event_designed_v1">>, maps:get(<<"event_type">>, Evt)),
    ?assertEqual(<<"order_placed_v1">>, maps:get(<<"event_name">>, Evt)).

exec_plan_desk() ->
    Cmd = #{<<"command_type">> => <<"plan_desk">>,
            <<"division_id">> => <<"div-1">>,
            <<"desk_name">> => <<"place_order">>,
            <<"description">> => <<"Place order desk">>,
            <<"department">> => <<"cmd">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(anp), Cmd),
    ?assertEqual(<<"desk_planned_v1">>, maps:get(<<"event_type">>, Evt)),
    ?assertEqual(<<"place_order">>, maps:get(<<"desk_name">>, Evt)).

exec_plan_dependency() ->
    Cmd = #{<<"command_type">> => <<"plan_dependency">>,
            <<"division_id">> => <<"div-1">>,
            <<"dependency_id">> => <<"dep-1">>,
            <<"from_desk">> => <<"place_order">>,
            <<"to_desk">> => <<"notify_warehouse">>,
            <<"dep_type">> => <<"event">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(anp), Cmd),
    ?assertEqual(<<"dependency_planned_v1">>, maps:get(<<"event_type">>, Evt)).

exec_generate_module() ->
    Cmd = #{<<"command_type">> => <<"generate_module">>,
            <<"division_id">> => <<"div-1">>,
            <<"module_name">> => <<"place_order_v1">>,
            <<"module_type">> => <<"command">>,
            <<"path">> => <<"src/place_order/place_order_v1.erl">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(tni), Cmd),
    ?assertEqual(<<"module_generated_v1">>, maps:get(<<"event_type">>, Evt)).

exec_generate_test() ->
    Cmd = #{<<"command_type">> => <<"generate_test">>,
            <<"division_id">> => <<"div-1">>,
            <<"test_name">> => <<"place_order_tests">>,
            <<"module_name">> => <<"place_order_v1">>,
            <<"path">> => <<"test/place_order_tests.erl">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(tni), Cmd),
    ?assertEqual(<<"test_generated_v1">>, maps:get(<<"event_type">>, Evt)).

exec_run_test_suite() ->
    Cmd = #{<<"command_type">> => <<"run_test_suite">>,
            <<"division_id">> => <<"div-1">>,
            <<"suite_id">> => <<"suite-1">>,
            <<"suite_name">> => <<"unit_tests">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(tni), Cmd),
    ?assertEqual(<<"test_suite_run_v1">>, maps:get(<<"event_type">>, Evt)).

exec_record_test_result() ->
    Cmd = #{<<"command_type">> => <<"record_test_result">>,
            <<"division_id">> => <<"div-1">>,
            <<"result_id">> => <<"res-1">>,
            <<"suite_id">> => <<"suite-1">>,
            <<"passed">> => 10, <<"failed">> => 2},
    {ok, [Evt]} = division_aggregate:execute(with_phase(tni), Cmd),
    ?assertEqual(<<"test_result_recorded_v1">>, maps:get(<<"event_type">>, Evt)).

exec_deploy_release() ->
    Cmd = #{<<"command_type">> => <<"deploy_release">>,
            <<"division_id">> => <<"div-1">>,
            <<"release_id">> => <<"rel-1">>,
            <<"version">> => <<"0.1.0">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dno), Cmd),
    ?assertEqual(<<"release_deployed_v1">>, maps:get(<<"event_type">>, Evt)).

exec_stage_rollout() ->
    Cmd = #{<<"command_type">> => <<"stage_rollout">>,
            <<"division_id">> => <<"div-1">>,
            <<"stage_id">> => <<"stg-1">>,
            <<"release_id">> => <<"rel-1">>,
            <<"stage_name">> => <<"canary">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dno), Cmd),
    ?assertEqual(<<"rollout_staged_v1">>, maps:get(<<"event_type">>, Evt)).

exec_register_health_check() ->
    Cmd = #{<<"command_type">> => <<"register_health_check">>,
            <<"division_id">> => <<"div-1">>,
            <<"check_id">> => <<"chk-1">>,
            <<"check_name">> => <<"api_health">>,
            <<"check_type">> => <<"http">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dno), Cmd),
    ?assertEqual(<<"health_check_registered_v1">>, maps:get(<<"event_type">>, Evt)).

exec_record_health_status() ->
    Cmd = #{<<"command_type">> => <<"record_health_status">>,
            <<"division_id">> => <<"div-1">>,
            <<"check_id">> => <<"chk-1">>,
            <<"status">> => <<"healthy">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dno), Cmd),
    ?assertEqual(<<"health_status_recorded_v1">>, maps:get(<<"event_type">>, Evt)).

exec_raise_incident() ->
    Cmd = #{<<"command_type">> => <<"raise_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"title">> => <<"API down">>,
            <<"severity">> => <<"critical">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dno), Cmd),
    ?assertEqual(<<"incident_raised_v1">>, maps:get(<<"event_type">>, Evt)).

exec_diagnose_incident() ->
    Cmd = #{<<"command_type">> => <<"diagnose_incident">>,
            <<"division_id">> => <<"div-1">>,
            <<"diagnosis_id">> => <<"diag-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"root_cause">> => <<"OOM">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dno), Cmd),
    ?assertEqual(<<"incident_diagnosed_v1">>, maps:get(<<"event_type">>, Evt)).

exec_apply_fix() ->
    Cmd = #{<<"command_type">> => <<"apply_fix">>,
            <<"division_id">> => <<"div-1">>,
            <<"fix_id">> => <<"fix-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"description">> => <<"Increased memory limit">>},
    {ok, [Evt]} = division_aggregate:execute(with_phase(dno), Cmd),
    ?assertEqual(<<"fix_applied_v1">>, maps:get(<<"event_type">>, Evt)).

%% ===================================================================
%% Apply event tests
%% ===================================================================

apply_initiated() ->
    S = initiated(),
    ?assertEqual(<<"div-1">>, S#division_state.division_id),
    ?assertEqual(<<"v-1">>, S#division_state.venture_id),
    ?assertEqual(<<"auth">>, S#division_state.context_name),
    ?assertEqual(?DA_INITIATED, S#division_state.overall_status),
    ?assertEqual(1000, S#division_state.initiated_at),
    ?assertEqual(<<"user@test">>, S#division_state.initiated_by).

apply_archived() ->
    S = division_aggregate:apply_event(
        #{<<"event_type">> => <<"division_archived_v1">>}, initiated()),
    ?assert(S#division_state.overall_status band ?DA_ARCHIVED =/= 0),
    ?assert(S#division_state.overall_status band ?DA_INITIATED =/= 0).

apply_phase_started() ->
    S = with_phase(dna),
    ?assertEqual(?PHASE_ACTIVE, S#division_state.dna_status),
    ?assert(is_integer(S#division_state.dna_started_at)).

apply_phase_paused() ->
    S = with_phase_paused(dna),
    ?assert(S#division_state.dna_status band ?PHASE_PAUSED =/= 0),
    ?assert(S#division_state.dna_status band ?PHASE_ACTIVE =:= 0),
    ?assertEqual(<<"blocked">>, S#division_state.dna_pause_reason).

apply_phase_resumed() ->
    S0 = with_phase_paused(anp),
    S1 = division_aggregate:apply_event(
        #{<<"event_type">> => <<"phase_resumed_v1">>,
          <<"division_id">> => <<"div-1">>,
          <<"phase">> => <<"anp">>}, S0),
    ?assert(S1#division_state.anp_status band ?PHASE_ACTIVE =/= 0),
    ?assert(S1#division_state.anp_status band ?PHASE_PAUSED =:= 0),
    ?assertEqual(undefined, S1#division_state.anp_pause_reason).

apply_phase_completed() ->
    S0 = with_phase(tni),
    S1 = division_aggregate:apply_event(
        #{<<"event_type">> => <<"phase_completed_v1">>,
          <<"division_id">> => <<"div-1">>,
          <<"phase">> => <<"tni">>,
          <<"completed_at">> => 5000}, S0),
    ?assert(S1#division_state.tni_status band ?PHASE_COMPLETED =/= 0),
    ?assert(S1#division_state.tni_status band ?PHASE_ACTIVE =:= 0),
    ?assertEqual(5000, S1#division_state.tni_completed_at).

apply_aggregate_designed() ->
    Evt = #{<<"event_type">> => <<"aggregate_designed_v1">>,
            <<"aggregate_name">> => <<"order">>,
            <<"description">> => <<"Order agg">>,
            <<"stream_prefix">> => <<"order-">>,
            <<"fields">> => [<<"id">>, <<"status">>]},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"order">>, S#division_state.designed_aggregates)),
    Details = maps:get(<<"order">>, S#division_state.designed_aggregates),
    ?assertEqual(<<"order">>, maps:get(aggregate_name, Details)),
    ?assertEqual(<<"Order agg">>, maps:get(description, Details)).

apply_event_designed() ->
    Evt = #{<<"event_type">> => <<"event_designed_v1">>,
            <<"event_name">> => <<"order_placed_v1">>,
            <<"description">> => <<"Placed event">>,
            <<"aggregate_name">> => <<"order">>,
            <<"fields">> => [<<"order_id">>]},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"order_placed_v1">>, S#division_state.designed_events)).

apply_desk_planned() ->
    Evt = #{<<"event_type">> => <<"desk_planned_v1">>,
            <<"desk_name">> => <<"place_order">>,
            <<"description">> => <<"Desk">>,
            <<"department">> => <<"cmd">>,
            <<"commands">> => [<<"place_order_v1">>]},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"place_order">>, S#division_state.planned_desks)).

apply_dependency_planned() ->
    Evt = #{<<"event_type">> => <<"dependency_planned_v1">>,
            <<"dependency_id">> => <<"dep-1">>,
            <<"from_desk">> => <<"place_order">>,
            <<"to_desk">> => <<"notify">>,
            <<"dep_type">> => <<"event">>},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"dep-1">>, S#division_state.planned_dependencies)).

apply_module_generated() ->
    Evt = #{<<"event_type">> => <<"module_generated_v1">>,
            <<"module_name">> => <<"place_order_v1">>,
            <<"module_type">> => <<"command">>,
            <<"path">> => <<"src/place_order_v1.erl">>},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"place_order_v1">>, S#division_state.generated_modules)).

apply_test_generated() ->
    Evt = #{<<"event_type">> => <<"test_generated_v1">>,
            <<"test_name">> => <<"order_tests">>,
            <<"module_name">> => <<"order">>,
            <<"path">> => <<"test/order_tests.erl">>},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"order_tests">>, S#division_state.generated_tests)).

apply_test_suite_run() ->
    Evt = #{<<"event_type">> => <<"test_suite_run_v1">>,
            <<"suite_id">> => <<"suite-1">>,
            <<"suite_name">> => <<"unit">>,
            <<"run_at">> => 3000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"suite-1">>, S#division_state.test_suites)).

apply_test_result_recorded() ->
    Evt = #{<<"event_type">> => <<"test_result_recorded_v1">>,
            <<"result_id">> => <<"res-1">>,
            <<"suite_id">> => <<"suite-1">>,
            <<"passed">> => 10, <<"failed">> => 2,
            <<"recorded_at">> => 4000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"res-1">>, S#division_state.test_results)),
    R = maps:get(<<"res-1">>, S#division_state.test_results),
    ?assertEqual(10, maps:get(passed, R)),
    ?assertEqual(2, maps:get(failed, R)).

apply_release_deployed() ->
    Evt = #{<<"event_type">> => <<"release_deployed_v1">>,
            <<"release_id">> => <<"rel-1">>,
            <<"version">> => <<"0.1.0">>,
            <<"deployed_at">> => 5000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"rel-1">>, S#division_state.releases)),
    R = maps:get(<<"rel-1">>, S#division_state.releases),
    ?assertEqual(<<"0.1.0">>, maps:get(version, R)).

apply_rollout_staged() ->
    Evt = #{<<"event_type">> => <<"rollout_staged_v1">>,
            <<"stage_id">> => <<"stg-1">>,
            <<"release_id">> => <<"rel-1">>,
            <<"stage_name">> => <<"canary">>,
            <<"staged_at">> => 6000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"stg-1">>, S#division_state.rollout_stages)).

apply_health_check_registered() ->
    Evt = #{<<"event_type">> => <<"health_check_registered_v1">>,
            <<"check_id">> => <<"chk-1">>,
            <<"check_name">> => <<"api_health">>,
            <<"check_type">> => <<"http">>,
            <<"registered_at">> => 7000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"chk-1">>, S#division_state.health_checks)).

apply_health_status_recorded() ->
    %% First register the check, then record status
    S0 = division_aggregate:apply_event(
        #{<<"event_type">> => <<"health_check_registered_v1">>,
          <<"check_id">> => <<"chk-1">>,
          <<"check_name">> => <<"api_health">>,
          <<"check_type">> => <<"http">>,
          <<"registered_at">> => 7000}, initiated()),
    S1 = division_aggregate:apply_event(
        #{<<"event_type">> => <<"health_status_recorded_v1">>,
          <<"check_id">> => <<"chk-1">>,
          <<"status">> => <<"healthy">>,
          <<"recorded_at">> => 8000}, S0),
    Check = maps:get(<<"chk-1">>, S1#division_state.health_checks),
    ?assertEqual(<<"healthy">>, maps:get(last_status, Check)),
    ?assertEqual(8000, maps:get(last_checked_at, Check)).

apply_incident_raised() ->
    Evt = #{<<"event_type">> => <<"incident_raised_v1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"title">> => <<"API down">>,
            <<"severity">> => <<"critical">>,
            <<"raised_at">> => 9000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"inc-1">>, S#division_state.incidents)),
    I = maps:get(<<"inc-1">>, S#division_state.incidents),
    ?assertEqual(<<"critical">>, maps:get(severity, I)).

apply_incident_diagnosed() ->
    Evt = #{<<"event_type">> => <<"incident_diagnosed_v1">>,
            <<"diagnosis_id">> => <<"diag-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"root_cause">> => <<"OOM">>,
            <<"diagnosed_at">> => 10000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"diag-1">>, S#division_state.diagnoses)),
    D = maps:get(<<"diag-1">>, S#division_state.diagnoses),
    ?assertEqual(<<"OOM">>, maps:get(root_cause, D)).

apply_fix_applied() ->
    Evt = #{<<"event_type">> => <<"fix_applied_v1">>,
            <<"fix_id">> => <<"fix-1">>,
            <<"incident_id">> => <<"inc-1">>,
            <<"description">> => <<"Bumped memory">>,
            <<"applied_at">> => 11000},
    S = division_aggregate:apply_event(Evt, initiated()),
    ?assert(maps:is_key(<<"fix-1">>, S#division_state.fixes)),
    F = maps:get(<<"fix-1">>, S#division_state.fixes),
    ?assertEqual(<<"Bumped memory">>, maps:get(description, F)).

apply_unknown_event() ->
    S0 = initiated(),
    S1 = division_aggregate:apply_event(
        #{<<"event_type">> => <<"something_unknown_v1">>}, S0),
    ?assertEqual(S0, S1).

%% ===================================================================
%% Full lifecycle integration test
%% ===================================================================

full_lifecycle() ->
    %% Initiate
    {ok, [InitEvt]} = division_aggregate:execute(fresh(), initiate_cmd()),
    S0 = division_aggregate:apply_event(InitEvt, fresh()),
    ?assert(S0#division_state.overall_status band ?DA_INITIATED =/= 0),

    %% Start DnA phase
    {ok, [DnaStartEvt]} = division_aggregate:execute(S0,
        #{<<"command_type">> => <<"start_phase">>,
          <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>}),
    S1 = division_aggregate:apply_event(DnaStartEvt, S0),
    ?assertEqual(?PHASE_ACTIVE, S1#division_state.dna_status),

    %% Design an aggregate (dna active)
    {ok, [AggEvt]} = division_aggregate:execute(S1,
        #{<<"command_type">> => <<"design_aggregate">>,
          <<"division_id">> => <<"div-1">>,
          <<"aggregate_name">> => <<"order">>,
          <<"description">> => <<"Order agg">>}),
    S2 = division_aggregate:apply_event(AggEvt, S1),
    ?assert(maps:is_key(<<"order">>, S2#division_state.designed_aggregates)),

    %% Complete DnA
    {ok, [DnaCompleteEvt]} = division_aggregate:execute(S2,
        #{<<"command_type">> => <<"complete_phase">>,
          <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>}),
    S3 = division_aggregate:apply_event(DnaCompleteEvt, S2),
    ?assert(S3#division_state.dna_status band ?PHASE_COMPLETED =/= 0),

    %% Start AnP
    {ok, [AnpStartEvt]} = division_aggregate:execute(S3,
        #{<<"command_type">> => <<"start_phase">>,
          <<"division_id">> => <<"div-1">>, <<"phase">> => <<"anp">>}),
    S4 = division_aggregate:apply_event(AnpStartEvt, S3),

    %% Plan a desk (anp active)
    {ok, [DeskEvt]} = division_aggregate:execute(S4,
        #{<<"command_type">> => <<"plan_desk">>,
          <<"division_id">> => <<"div-1">>,
          <<"desk_name">> => <<"place_order">>,
          <<"description">> => <<"Place order desk">>}),
    S5 = division_aggregate:apply_event(DeskEvt, S4),
    ?assert(maps:is_key(<<"place_order">>, S5#division_state.planned_desks)),

    %% Complete AnP, start TnI
    {ok, [AnpCompleteEvt]} = division_aggregate:execute(S5,
        #{<<"command_type">> => <<"complete_phase">>,
          <<"division_id">> => <<"div-1">>, <<"phase">> => <<"anp">>}),
    S6 = division_aggregate:apply_event(AnpCompleteEvt, S5),

    {ok, [TniStartEvt]} = division_aggregate:execute(S6,
        #{<<"command_type">> => <<"start_phase">>,
          <<"division_id">> => <<"div-1">>, <<"phase">> => <<"tni">>}),
    S7 = division_aggregate:apply_event(TniStartEvt, S6),

    %% Complete TnI, start DnO
    {ok, [TniCompleteEvt]} = division_aggregate:execute(S7,
        #{<<"command_type">> => <<"complete_phase">>,
          <<"division_id">> => <<"div-1">>, <<"phase">> => <<"tni">>}),
    S8 = division_aggregate:apply_event(TniCompleteEvt, S7),

    {ok, [DnoStartEvt]} = division_aggregate:execute(S8,
        #{<<"command_type">> => <<"start_phase">>,
          <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dno">>}),
    S9 = division_aggregate:apply_event(DnoStartEvt, S8),
    ?assertEqual(?PHASE_ACTIVE, S9#division_state.dno_status),

    %% Archive
    {ok, [ArchEvt]} = division_aggregate:execute(S9,
        #{<<"command_type">> => <<"archive_division">>,
          <<"division_id">> => <<"div-1">>, <<"reason">> => <<"done">>}),
    S10 = division_aggregate:apply_event(ArchEvt, S9),
    ?assert(S10#division_state.overall_status band ?DA_ARCHIVED =/= 0),

    %% Verify archived rejects commands
    ?assertEqual({error, division_archived},
                 division_aggregate:execute(S10,
                     #{<<"command_type">> => <<"start_phase">>,
                       <<"division_id">> => <<"div-1">>, <<"phase">> => <<"dna">>})).
