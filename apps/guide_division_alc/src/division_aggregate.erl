%%% @doc Division aggregate — unified ALC lifecycle for all phases.
%%%
%%% Absorbs: design_aggregate, plan_aggregate, generation_aggregate,
%%%          testing_aggregate, deployment_aggregate, monitoring_aggregate,
%%%          rescue_aggregate
%%% Stream: division-{division_id}
%%% Store: dev_studio_store
%%%
%%% Phases (parameterized lifecycle):
%%%   dna — Discovery & Analysis (was design_division)
%%%   anp — Architecture & Planning (was plan_division)
%%%   tni — Testing & Implementation (was generate_division + test_division)
%%%   dno — Deployment & Operations (was deploy + monitor + rescue)
%%%
%%% Each phase: start_phase -> pause_phase/resume_phase -> complete_phase
%%% Division overall: initiate_division -> ... -> archive_division
%%% @end
-module(division_aggregate).

-behaviour(evoq_aggregate).

-include("division_alc_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).

-record(division_state, {
    division_id    :: binary() | undefined,
    venture_id     :: binary() | undefined,
    context_name   :: binary() | undefined,
    overall_status = 0 :: non_neg_integer(),
    %% Per-phase status
    dna_status = 0 :: non_neg_integer(),
    anp_status = 0 :: non_neg_integer(),
    tni_status = 0 :: non_neg_integer(),
    dno_status = 0 :: non_neg_integer(),
    %% Per-phase timestamps
    dna_started_at :: non_neg_integer() | undefined,
    dna_paused_at  :: non_neg_integer() | undefined,
    dna_completed_at :: non_neg_integer() | undefined,
    dna_pause_reason :: binary() | undefined,
    anp_started_at :: non_neg_integer() | undefined,
    anp_paused_at  :: non_neg_integer() | undefined,
    anp_completed_at :: non_neg_integer() | undefined,
    anp_pause_reason :: binary() | undefined,
    tni_started_at :: non_neg_integer() | undefined,
    tni_paused_at  :: non_neg_integer() | undefined,
    tni_completed_at :: non_neg_integer() | undefined,
    tni_pause_reason :: binary() | undefined,
    dno_started_at :: non_neg_integer() | undefined,
    dno_paused_at  :: non_neg_integer() | undefined,
    dno_completed_at :: non_neg_integer() | undefined,
    dno_pause_reason :: binary() | undefined,
    %% AnP domain data
    designed_aggregates = #{} :: map(),
    designed_events = #{} :: map(),
    planned_desks = #{} :: map(),
    planned_dependencies = #{} :: map(),
    %% TnI domain data
    generated_modules = #{} :: map(),
    generated_tests = #{} :: map(),
    test_suites = #{} :: map(),
    test_results = #{} :: map(),
    %% DnO domain data
    releases = #{} :: map(),
    rollout_stages = #{} :: map(),
    health_checks = #{} :: map(),
    incidents = #{} :: map(),
    diagnoses = #{} :: map(),
    fixes = #{} :: map(),
    %% Meta
    initiated_at :: non_neg_integer() | undefined,
    initiated_by :: binary() | undefined
}).

-type state() :: #division_state{}.
-export_type([state/0]).

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #division_state{}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate allowed
execute(#division_state{overall_status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_division">> -> execute_initiate_division(Payload);
        _ -> {error, division_not_initiated}
    end;

%% Archived — nothing allowed
execute(#division_state{overall_status = S}, _Payload) when S band ?DA_ARCHIVED =/= 0 ->
    {error, division_archived};

%% Initiated and not archived — route by command type
execute(#division_state{overall_status = S} = State, Payload) when S band ?DA_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        %% Phase lifecycle (generic)
        <<"start_phase">>    -> execute_start_phase(Payload, State);
        <<"pause_phase">>    -> execute_pause_phase(Payload, State);
        <<"resume_phase">>   -> execute_resume_phase(Payload, State);
        <<"complete_phase">> -> execute_complete_phase(Payload, State);
        <<"archive_division">> -> execute_archive_division(Payload, State);
        %% DnA domain commands (require dna phase active)
        <<"design_aggregate">> -> execute_in_phase(dna, Payload, State, fun execute_design_aggregate/2);
        <<"design_event">>     -> execute_in_phase(dna, Payload, State, fun execute_design_event/2);
        %% AnP domain commands (require anp phase active)
        <<"plan_desk">>        -> execute_in_phase(anp, Payload, State, fun execute_plan_desk/2);
        <<"plan_dependency">>  -> execute_in_phase(anp, Payload, State, fun execute_plan_dependency/2);
        %% TnI domain commands (require tni phase active)
        <<"generate_module">>     -> execute_in_phase(tni, Payload, State, fun execute_generate_module/2);
        <<"generate_test">>       -> execute_in_phase(tni, Payload, State, fun execute_generate_test/2);
        <<"run_test_suite">>      -> execute_in_phase(tni, Payload, State, fun execute_run_test_suite/2);
        <<"record_test_result">>  -> execute_in_phase(tni, Payload, State, fun execute_record_test_result/2);
        %% DnO domain commands (require dno phase active)
        <<"deploy_release">>         -> execute_in_phase(dno, Payload, State, fun execute_deploy_release/2);
        <<"stage_rollout">>          -> execute_in_phase(dno, Payload, State, fun execute_stage_rollout/2);
        <<"register_health_check">>  -> execute_in_phase(dno, Payload, State, fun execute_register_health_check/2);
        <<"record_health_status">>   -> execute_in_phase(dno, Payload, State, fun execute_record_health_status/2);
        <<"raise_incident">>         -> execute_in_phase(dno, Payload, State, fun execute_raise_incident/2);
        <<"diagnose_incident">>      -> execute_in_phase(dno, Payload, State, fun execute_diagnose_incident/2);
        <<"apply_fix">>              -> execute_in_phase(dno, Payload, State, fun execute_apply_fix/2);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Phase gate: only allow domain commands when phase is active ---

execute_in_phase(Phase, Payload, State, Fun) ->
    PhaseStatus = get_phase_status(Phase, State),
    case PhaseStatus band ?PHASE_ACTIVE of
        0 -> {error, {phase_not_active, Phase}};
        _ -> Fun(Payload, State)
    end.

%% --- Lifecycle command handlers ---

execute_initiate_division(Payload) ->
    {ok, Cmd} = initiate_division_v1:from_map(Payload),
    convert_events(maybe_initiate_division:handle(Cmd), fun division_initiated_v1:to_map/1).

execute_start_phase(Payload, State) ->
    case validate_phase(Payload) of
        {ok, Phase} ->
            PhaseStatus = get_phase_status(Phase, State),
            case PhaseStatus of
                0 ->
                    {ok, Cmd} = start_phase_v1:from_map(Payload),
                    convert_events(maybe_start_phase:handle(Cmd), fun phase_started_v1:to_map/1);
                _ ->
                    {error, {phase_already_started, Phase}}
            end;
        {error, _} = Err -> Err
    end.

execute_pause_phase(Payload, State) ->
    case validate_phase(Payload) of
        {ok, Phase} ->
            PhaseStatus = get_phase_status(Phase, State),
            case PhaseStatus band ?PHASE_ACTIVE of
                0 -> {error, {phase_not_active, Phase}};
                _ ->
                    {ok, Cmd} = pause_phase_v1:from_map(Payload),
                    convert_events(maybe_pause_phase:handle(Cmd), fun phase_paused_v1:to_map/1)
            end;
        {error, _} = Err -> Err
    end.

execute_resume_phase(Payload, State) ->
    case validate_phase(Payload) of
        {ok, Phase} ->
            PhaseStatus = get_phase_status(Phase, State),
            case PhaseStatus band ?PHASE_PAUSED of
                0 -> {error, {phase_not_paused, Phase}};
                _ ->
                    {ok, Cmd} = resume_phase_v1:from_map(Payload),
                    convert_events(maybe_resume_phase:handle(Cmd), fun phase_resumed_v1:to_map/1)
            end;
        {error, _} = Err -> Err
    end.

execute_complete_phase(Payload, State) ->
    case validate_phase(Payload) of
        {ok, Phase} ->
            PhaseStatus = get_phase_status(Phase, State),
            case PhaseStatus band ?PHASE_ACTIVE of
                0 -> {error, {phase_not_active, Phase}};
                _ ->
                    {ok, Cmd} = complete_phase_v1:from_map(Payload),
                    convert_events(maybe_complete_phase:handle(Cmd), fun phase_completed_v1:to_map/1)
            end;
        {error, _} = Err -> Err
    end.

execute_archive_division(Payload, _State) ->
    {ok, Cmd} = archive_division_v1:from_map(Payload),
    convert_events(maybe_archive_division:handle(Cmd), fun division_archived_v1:to_map/1).

%% --- DnA domain command handlers ---

execute_design_aggregate(Payload, #division_state{designed_aggregates = Aggs}) ->
    {ok, Cmd} = design_aggregate_v1:from_map(Payload),
    Context = #{designed_aggregates => Aggs},
    convert_events(maybe_design_aggregate:handle(Cmd, Context), fun aggregate_designed_v1:to_map/1).

execute_design_event(Payload, #division_state{designed_events = Evts}) ->
    {ok, Cmd} = design_event_v1:from_map(Payload),
    Context = #{designed_events => Evts},
    convert_events(maybe_design_event:handle(Cmd, Context), fun event_designed_v1:to_map/1).

%% --- AnP domain command handlers ---

execute_plan_desk(Payload, #division_state{planned_desks = Desks}) ->
    {ok, Cmd} = plan_desk_v1:from_map(Payload),
    Context = #{planned_desks => Desks},
    convert_events(maybe_plan_desk:handle(Cmd, Context), fun desk_planned_v1:to_map/1).

execute_plan_dependency(Payload, #division_state{planned_dependencies = Deps}) ->
    {ok, Cmd} = plan_dependency_v1:from_map(Payload),
    Context = #{planned_dependencies => Deps},
    convert_events(maybe_plan_dependency:handle(Cmd, Context), fun dependency_planned_v1:to_map/1).

%% --- TnI domain command handlers ---

execute_generate_module(Payload, #division_state{generated_modules = Mods}) ->
    {ok, Cmd} = generate_module_v1:from_map(Payload),
    Context = #{generated_modules => Mods},
    convert_events(maybe_generate_module:handle(Cmd, Context), fun module_generated_v1:to_map/1).

execute_generate_test(Payload, #division_state{generated_tests = Tests}) ->
    {ok, Cmd} = generate_test_v1:from_map(Payload),
    Context = #{generated_tests => Tests},
    convert_events(maybe_generate_test:handle(Cmd, Context), fun test_generated_v1:to_map/1).

execute_run_test_suite(Payload, #division_state{test_suites = Suites}) ->
    {ok, Cmd} = run_test_suite_v1:from_map(Payload),
    Context = #{test_suites => Suites},
    convert_events(maybe_run_test_suite:handle(Cmd, Context), fun test_suite_run_v1:to_map/1).

execute_record_test_result(Payload, _State) ->
    {ok, Cmd} = record_test_result_v1:from_map(Payload),
    convert_events(maybe_record_test_result:handle(Cmd), fun test_result_recorded_v1:to_map/1).

%% --- DnO domain command handlers ---

execute_deploy_release(Payload, _State) ->
    {ok, Cmd} = deploy_release_v1:from_map(Payload),
    convert_events(maybe_deploy_release:handle(Cmd), fun release_deployed_v1:to_map/1).

execute_stage_rollout(Payload, _State) ->
    {ok, Cmd} = stage_rollout_v1:from_map(Payload),
    convert_events(maybe_stage_rollout:handle(Cmd), fun rollout_staged_v1:to_map/1).

execute_register_health_check(Payload, _State) ->
    {ok, Cmd} = register_health_check_v1:from_map(Payload),
    convert_events(maybe_register_health_check:handle(Cmd), fun health_check_registered_v1:to_map/1).

execute_record_health_status(Payload, _State) ->
    {ok, Cmd} = record_health_status_v1:from_map(Payload),
    convert_events(maybe_record_health_status:handle(Cmd), fun health_status_recorded_v1:to_map/1).

execute_raise_incident(Payload, _State) ->
    {ok, Cmd} = raise_incident_v1:from_map(Payload),
    convert_events(maybe_raise_incident:handle(Cmd), fun incident_raised_v1:to_map/1).

execute_diagnose_incident(Payload, _State) ->
    {ok, Cmd} = diagnose_incident_v1:from_map(Payload),
    convert_events(maybe_diagnose_incident:handle(Cmd), fun incident_diagnosed_v1:to_map/1).

execute_apply_fix(Payload, _State) ->
    {ok, Cmd} = apply_fix_v1:from_map(Payload),
    convert_events(maybe_apply_fix:handle(Cmd), fun fix_applied_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

%% Division lifecycle
apply_event(E, S) ->
    case get_event_type(E) of
        <<"division_initiated_v1">> -> apply_initiated(E, S);
        <<"division_archived_v1">>  -> apply_archived(S);
        %% Phase lifecycle
        <<"phase_started_v1">>   -> apply_phase_started(E, S);
        <<"phase_paused_v1">>    -> apply_phase_paused(E, S);
        <<"phase_resumed_v1">>   -> apply_phase_resumed(E, S);
        <<"phase_completed_v1">> -> apply_phase_completed(E, S);
        %% DnA domain
        <<"aggregate_designed_v1">> -> apply_aggregate_designed(E, S);
        <<"event_designed_v1">>     -> apply_event_designed(E, S);
        %% AnP domain
        <<"desk_planned_v1">>       -> apply_desk_planned(E, S);
        <<"dependency_planned_v1">> -> apply_dependency_planned(E, S);
        %% TnI domain
        <<"module_generated_v1">>    -> apply_module_generated(E, S);
        <<"test_generated_v1">>      -> apply_test_generated(E, S);
        <<"test_suite_run_v1">>      -> apply_test_suite_run(E, S);
        <<"test_result_recorded_v1">> -> apply_test_result_recorded(E, S);
        %% DnO domain
        <<"release_deployed_v1">>       -> apply_release_deployed(E, S);
        <<"rollout_staged_v1">>         -> apply_rollout_staged(E, S);
        <<"health_check_registered_v1">> -> apply_health_check_registered(E, S);
        <<"health_status_recorded_v1">>  -> apply_health_status_recorded(E, S);
        <<"incident_raised_v1">>         -> apply_incident_raised(E, S);
        <<"incident_diagnosed_v1">>      -> apply_incident_diagnosed(E, S);
        <<"fix_applied_v1">>             -> apply_fix_applied(E, S);
        _ -> S
    end.

%% --- Apply helpers: division lifecycle ---

apply_initiated(E, State) ->
    State#division_state{
        division_id = get_value(division_id, E),
        venture_id = get_value(venture_id, E),
        context_name = get_value(context_name, E),
        overall_status = evoq_bit_flags:set(0, ?DA_INITIATED),
        initiated_at = get_value(initiated_at, E),
        initiated_by = get_value(initiated_by, E)
    }.

apply_archived(State) ->
    State#division_state{
        overall_status = evoq_bit_flags:set(State#division_state.overall_status, ?DA_ARCHIVED)
    }.

%% --- Apply helpers: phase lifecycle ---

apply_phase_started(E, State) ->
    Phase = get_phase_atom(E),
    NewStatus = evoq_bit_flags:set(0, ?PHASE_ACTIVE),
    set_phase_status(Phase, NewStatus, State,
        fun(S) -> set_phase_timestamp(Phase, started_at, get_value(started_at, E), S) end).

apply_phase_paused(E, State) ->
    Phase = get_phase_atom(E),
    OldStatus = get_phase_status(Phase, State),
    S0 = evoq_bit_flags:unset(OldStatus, ?PHASE_ACTIVE),
    NewStatus = evoq_bit_flags:set(S0, ?PHASE_PAUSED),
    set_phase_status(Phase, NewStatus, State,
        fun(S) ->
            S1 = set_phase_timestamp(Phase, paused_at, get_value(paused_at, E), S),
            set_phase_field(Phase, pause_reason, get_value(reason, E), S1)
        end).

apply_phase_resumed(E, State) ->
    Phase = get_phase_atom(E),
    OldStatus = get_phase_status(Phase, State),
    S0 = evoq_bit_flags:unset(OldStatus, ?PHASE_PAUSED),
    NewStatus = evoq_bit_flags:set(S0, ?PHASE_ACTIVE),
    set_phase_status(Phase, NewStatus, State,
        fun(S) ->
            S1 = set_phase_timestamp(Phase, paused_at, undefined, S),
            set_phase_field(Phase, pause_reason, undefined, S1)
        end).

apply_phase_completed(E, State) ->
    Phase = get_phase_atom(E),
    OldStatus = get_phase_status(Phase, State),
    S0 = evoq_bit_flags:unset(OldStatus, ?PHASE_ACTIVE),
    NewStatus = evoq_bit_flags:set(S0, ?PHASE_COMPLETED),
    set_phase_status(Phase, NewStatus, State,
        fun(S) -> set_phase_timestamp(Phase, completed_at, get_value(completed_at, E), S) end).

%% --- Apply helpers: DnA domain ---

apply_aggregate_designed(E, #division_state{designed_aggregates = Aggs} = S) ->
    Name = get_value(aggregate_name, E),
    Details = #{
        aggregate_name => Name,
        description => get_value(description, E),
        stream_prefix => get_value(stream_prefix, E),
        fields => get_value(fields, E)
    },
    S#division_state{designed_aggregates = Aggs#{Name => Details}}.

apply_event_designed(E, #division_state{designed_events = Evts} = S) ->
    Name = get_value(event_name, E),
    Details = #{
        event_name => Name,
        description => get_value(description, E),
        aggregate_name => get_value(aggregate_name, E),
        fields => get_value(fields, E)
    },
    S#division_state{designed_events = Evts#{Name => Details}}.

%% --- Apply helpers: AnP domain ---

apply_desk_planned(E, #division_state{planned_desks = Desks} = S) ->
    Name = get_value(desk_name, E),
    Details = #{desk_name => Name, description => get_value(description, E),
                department => get_value(department, E), commands => get_value(commands, E)},
    S#division_state{planned_desks = Desks#{Name => Details}}.

apply_dependency_planned(E, #division_state{planned_dependencies = Deps} = S) ->
    Id = get_value(dependency_id, E),
    Details = #{dependency_id => Id, from_desk => get_value(from_desk, E),
                to_desk => get_value(to_desk, E), dep_type => get_value(dep_type, E)},
    S#division_state{planned_dependencies = Deps#{Id => Details}}.

%% --- Apply helpers: TnI domain ---

apply_module_generated(E, #division_state{generated_modules = Mods} = S) ->
    Name = get_value(module_name, E),
    Details = #{module_name => Name, module_type => get_value(module_type, E),
                path => get_value(path, E)},
    S#division_state{generated_modules = Mods#{Name => Details}}.

apply_test_generated(E, #division_state{generated_tests = Tests} = S) ->
    Name = get_value(test_name, E),
    Details = #{test_name => Name, module_name => get_value(module_name, E),
                path => get_value(path, E)},
    S#division_state{generated_tests = Tests#{Name => Details}}.

apply_test_suite_run(E, #division_state{test_suites = Suites} = S) ->
    Id = get_value(suite_id, E),
    Details = #{suite_id => Id, suite_name => get_value(suite_name, E),
                run_at => get_value(run_at, E)},
    S#division_state{test_suites = Suites#{Id => Details}}.

apply_test_result_recorded(E, #division_state{test_results = Results} = S) ->
    Id = get_value(result_id, E),
    Details = #{result_id => Id, suite_id => get_value(suite_id, E),
                passed => get_value(passed, E), failed => get_value(failed, E),
                recorded_at => get_value(recorded_at, E)},
    S#division_state{test_results = Results#{Id => Details}}.

%% --- Apply helpers: DnO domain ---

apply_release_deployed(E, #division_state{releases = Rels} = S) ->
    Id = get_value(release_id, E),
    Details = #{release_id => Id, version => get_value(version, E),
                deployed_at => get_value(deployed_at, E)},
    S#division_state{releases = Rels#{Id => Details}}.

apply_rollout_staged(E, #division_state{rollout_stages = Stages} = S) ->
    Id = get_value(stage_id, E),
    Details = #{stage_id => Id, release_id => get_value(release_id, E),
                stage_name => get_value(stage_name, E), staged_at => get_value(staged_at, E)},
    S#division_state{rollout_stages = Stages#{Id => Details}}.

apply_health_check_registered(E, #division_state{health_checks = Checks} = S) ->
    Id = get_value(check_id, E),
    Details = #{check_id => Id, check_name => get_value(check_name, E),
                check_type => get_value(check_type, E), registered_at => get_value(registered_at, E)},
    S#division_state{health_checks = Checks#{Id => Details}}.

apply_health_status_recorded(E, S) ->
    %% Updates existing health check with latest status
    Id = get_value(check_id, E),
    Checks = S#division_state.health_checks,
    Existing = maps:get(Id, Checks, #{}),
    Updated = Existing#{last_status => get_value(status, E),
                        last_checked_at => get_value(recorded_at, E)},
    S#division_state{health_checks = Checks#{Id => Updated}}.

apply_incident_raised(E, #division_state{incidents = Incidents} = S) ->
    Id = get_value(incident_id, E),
    Details = #{incident_id => Id, title => get_value(title, E),
                severity => get_value(severity, E), raised_at => get_value(raised_at, E)},
    S#division_state{incidents = Incidents#{Id => Details}}.

apply_incident_diagnosed(E, #division_state{diagnoses = Diags} = S) ->
    Id = get_value(diagnosis_id, E),
    Details = #{diagnosis_id => Id, incident_id => get_value(incident_id, E),
                root_cause => get_value(root_cause, E), diagnosed_at => get_value(diagnosed_at, E)},
    S#division_state{diagnoses = Diags#{Id => Details}}.

apply_fix_applied(E, #division_state{fixes = Fixes} = S) ->
    Id = get_value(fix_id, E),
    Details = #{fix_id => Id, incident_id => get_value(incident_id, E),
                description => get_value(description, E), applied_at => get_value(applied_at, E)},
    S#division_state{fixes = Fixes#{Id => Details}}.

%% --- Phase status accessors ---

get_phase_status(dna, #division_state{dna_status = S}) -> S;
get_phase_status(anp, #division_state{anp_status = S}) -> S;
get_phase_status(tni, #division_state{tni_status = S}) -> S;
get_phase_status(dno, #division_state{dno_status = S}) -> S.

set_phase_status(Phase, NewStatus, State, AfterFun) ->
    S1 = case Phase of
        dna -> State#division_state{dna_status = NewStatus};
        anp -> State#division_state{anp_status = NewStatus};
        tni -> State#division_state{tni_status = NewStatus};
        dno -> State#division_state{dno_status = NewStatus}
    end,
    AfterFun(S1).

set_phase_timestamp(dna, started_at, V, S) -> S#division_state{dna_started_at = V};
set_phase_timestamp(dna, paused_at, V, S)  -> S#division_state{dna_paused_at = V};
set_phase_timestamp(dna, completed_at, V, S) -> S#division_state{dna_completed_at = V};
set_phase_timestamp(anp, started_at, V, S) -> S#division_state{anp_started_at = V};
set_phase_timestamp(anp, paused_at, V, S)  -> S#division_state{anp_paused_at = V};
set_phase_timestamp(anp, completed_at, V, S) -> S#division_state{anp_completed_at = V};
set_phase_timestamp(tni, started_at, V, S) -> S#division_state{tni_started_at = V};
set_phase_timestamp(tni, paused_at, V, S)  -> S#division_state{tni_paused_at = V};
set_phase_timestamp(tni, completed_at, V, S) -> S#division_state{tni_completed_at = V};
set_phase_timestamp(dno, started_at, V, S) -> S#division_state{dno_started_at = V};
set_phase_timestamp(dno, paused_at, V, S)  -> S#division_state{dno_paused_at = V};
set_phase_timestamp(dno, completed_at, V, S) -> S#division_state{dno_completed_at = V}.

set_phase_field(dna, pause_reason, V, S) -> S#division_state{dna_pause_reason = V};
set_phase_field(anp, pause_reason, V, S) -> S#division_state{anp_pause_reason = V};
set_phase_field(tni, pause_reason, V, S) -> S#division_state{tni_pause_reason = V};
set_phase_field(dno, pause_reason, V, S) -> S#division_state{dno_pause_reason = V}.

%% --- Internal ---

get_event_type(#{<<"event_type">> := T}) -> T;
get_event_type(#{event_type := T}) when is_binary(T) -> T;
get_event_type(_) -> undefined.

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_phase_atom(E) ->
    Phase = get_value(phase, E),
    case Phase of
        <<"dna">> -> dna;
        <<"anp">> -> anp;
        <<"tni">> -> tni;
        <<"dno">> -> dno;
        A when is_atom(A) -> A;
        _ -> undefined
    end.

validate_phase(Payload) ->
    Phase = get_value(phase, Payload),
    case Phase of
        <<"dna">> -> {ok, dna};
        <<"anp">> -> {ok, anp};
        <<"tni">> -> {ok, tni};
        <<"dno">> -> {ok, dno};
        _ -> {error, invalid_phase}
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
