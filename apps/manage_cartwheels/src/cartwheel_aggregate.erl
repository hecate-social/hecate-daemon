%%% @doc Cartwheel aggregate
%%% Maintains Cartwheel state and applies events.
%%% Handles orchestration events (initiate_cartwheel, transition_phase, revisit_phase)
%%% and DnA events (discovery_started, finding_recorded, term_defined, discovery_completed).
-module(cartwheel_aggregate).

-export([execute/2, apply_event/2, initial_state/0]).

-define(INITIATED,             1).   %% 2^0
-define(DISCOVERY_ACTIVE,      2).   %% 2^1
-define(DISCOVERY_COMPLETE,    4).   %% 2^2
-define(ARCHITECTURE_ACTIVE,   8).   %% 2^3
-define(ARCHITECTURE_COMPLETE,16).   %% 2^4
-define(TESTING_ACTIVE,       32).   %% 2^5
-define(TESTING_COMPLETE,     64).   %% 2^6
-define(DEPLOYMENT_ACTIVE,   128).   %% 2^7
-define(DEPLOYMENT_COMPLETE, 256).   %% 2^8
-define(COMPLETED,           512).   %% 2^9
-define(REVISITING,         1024).   %% 2^10

-record(cartwheel_state, {
    cartwheel_id           :: binary() | undefined,
    torch_id               :: binary() | undefined,      %% Parent Torch
    context_name           :: binary() | undefined,      %% Bounded context name
    current_phase          :: binary() | undefined,
    status                 :: non_neg_integer(),
    finding_count          :: non_neg_integer(),
    term_count             :: non_neg_integer(),
    dossier_count          :: non_neg_integer(),
    spoke_count            :: non_neg_integer(),
    plan_approved          :: boolean(),
    skeleton_created       :: boolean(),
    implemented_spoke_count :: non_neg_integer(),
    build_verified         :: boolean(),
    deployment_count       :: non_neg_integer(),
    active_incidents       :: non_neg_integer(),
    initiated_at           :: non_neg_integer() | undefined,
    phase_started_at       :: non_neg_integer() | undefined,
    completed_at           :: non_neg_integer() | undefined
}).

-type state() :: #cartwheel_state{}.
-export_type([state/0]).

-spec initial_state() -> state().
initial_state() ->
    #cartwheel_state{
        cartwheel_id = undefined,
        torch_id = undefined,
        context_name = undefined,
        current_phase = undefined,
        status = 0,
        finding_count = 0,
        term_count = 0,
        dossier_count = 0,
        spoke_count = 0,
        plan_approved = false,
        skeleton_created = false,
        implemented_spoke_count = 0,
        build_verified = false,
        deployment_count = 0,
        active_incidents = 0,
        initiated_at = undefined,
        phase_started_at = undefined,
        completed_at = undefined
    }.

%% @doc Execute command against aggregate state
-spec execute(map(), state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := <<"initiate_cartwheel">>} = Payload, State) ->
    execute_initiate_cartwheel(Payload, State);
execute(#{command_type := <<"start_discovery">>} = Payload, State) ->
    execute_start_discovery(Payload, State);
execute(#{command_type := <<"record_finding">>} = Payload, State) ->
    execute_record_finding(Payload, State);
execute(#{command_type := <<"define_term">>} = Payload, State) ->
    execute_define_term(Payload, State);
execute(#{command_type := <<"complete_discovery">>} = Payload, State) ->
    execute_complete_discovery(Payload, State);
execute(#{command_type := <<"transition_phase">>} = Payload, State) ->
    execute_transition_phase(Payload, State);
execute(#{command_type := <<"start_architecture">>} = Payload, State) ->
    execute_start_architecture(Payload, State);
execute(#{command_type := <<"define_dossier">>} = Payload, State) ->
    execute_define_dossier(Payload, State);
execute(#{command_type := <<"inventory_spoke">>} = Payload, State) ->
    execute_inventory_spoke(Payload, State);
execute(#{command_type := <<"draft_plan">>} = Payload, State) ->
    execute_draft_plan(Payload, State);
execute(#{command_type := <<"approve_plan">>} = Payload, State) ->
    execute_approve_plan(Payload, State);
execute(#{command_type := <<"complete_architecture">>} = Payload, State) ->
    execute_complete_architecture(Payload, State);
execute(#{command_type := <<"start_testing">>} = Payload, State) ->
    execute_start_testing(Payload, State);
execute(#{command_type := <<"create_skeleton">>} = Payload, State) ->
    execute_create_skeleton(Payload, State);
execute(#{command_type := <<"implement_spoke">>} = Payload, State) ->
    execute_implement_spoke(Payload, State);
execute(#{command_type := <<"verify_build">>} = Payload, State) ->
    execute_verify_build(Payload, State);
execute(#{command_type := <<"complete_testing">>} = Payload, State) ->
    execute_complete_testing(Payload, State);
execute(#{command_type := <<"start_deployment">>} = Payload, State) ->
    execute_start_deployment(Payload, State);
execute(#{command_type := <<"record_deployment">>} = Payload, State) ->
    execute_record_deployment(Payload, State);
execute(#{command_type := <<"report_incident">>} = Payload, State) ->
    execute_report_incident(Payload, State);
execute(#{command_type := <<"resolve_incident">>} = Payload, State) ->
    execute_resolve_incident(Payload, State);
execute(#{command_type := <<"complete_deployment">>} = Payload, State) ->
    execute_complete_deployment(Payload, State);
execute(_Payload, _State) ->
    {error, unknown_command}.

execute_initiate_cartwheel(Payload, #cartwheel_state{status = 0}) ->
    {ok, Cmd} = initiate_cartwheel_v1:from_map(Payload),
    convert_events(maybe_initiate_cartwheel:handle(Cmd), fun cartwheel_initiated_v1:to_map/1);
execute_initiate_cartwheel(_Payload, _State) ->
    {error, cartwheel_already_initiated}.

execute_start_discovery(Payload, #cartwheel_state{current_phase = <<"discovery_n_analysis">>}) ->
    {ok, Cmd} = start_discovery_v1:from_map(Payload),
    convert_events(maybe_start_discovery:handle(Cmd), fun discovery_started_v1:to_map/1);
execute_start_discovery(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_start_discovery(_Payload, _State) ->
    {error, not_in_discovery_phase}.

execute_record_finding(Payload, #cartwheel_state{current_phase = <<"discovery_n_analysis">>}) ->
    {ok, Cmd} = record_finding_v1:from_map(Payload),
    convert_events(maybe_record_finding:handle(Cmd), fun finding_recorded_v1:to_map/1);
execute_record_finding(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_record_finding(_Payload, _State) ->
    {error, not_in_discovery_phase}.

execute_define_term(Payload, #cartwheel_state{current_phase = <<"discovery_n_analysis">>}) ->
    {ok, Cmd} = define_term_v1:from_map(Payload),
    convert_events(maybe_define_term:handle(Cmd), fun term_defined_v1:to_map/1);
execute_define_term(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_define_term(_Payload, _State) ->
    {error, not_in_discovery_phase}.

execute_complete_discovery(Payload, #cartwheel_state{current_phase = <<"discovery_n_analysis">>, finding_count = FC, term_count = TC})
  when FC > 0, TC > 0 ->
    {ok, Cmd} = complete_discovery_v1:from_map(Payload),
    convert_events(maybe_complete_discovery:handle(Cmd), fun discovery_completed_v1:to_map/1);
execute_complete_discovery(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_complete_discovery(_Payload, #cartwheel_state{current_phase = Phase}) when Phase =/= <<"discovery_n_analysis">> ->
    {error, not_in_discovery_phase};
execute_complete_discovery(_Payload, #cartwheel_state{finding_count = 0}) ->
    {error, no_findings_recorded};
execute_complete_discovery(_Payload, #cartwheel_state{term_count = 0}) ->
    {error, no_terms_defined}.

execute_transition_phase(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_transition_phase(Payload, #cartwheel_state{current_phase = CurrentPhase} = State) ->
    {ok, Cmd} = transition_phase_v1:from_map(Payload),
    FromPhase = transition_phase_v1:get_from_phase(Cmd),
    case FromPhase =:= CurrentPhase of
        false ->
            {error, invalid_phase_transition};
        true ->
            case check_gate(State) of
                ok ->
                    convert_events(maybe_transition_phase:handle(Cmd), fun phase_transitioned_v1:to_map/1);
                {error, Reason} ->
                    {error, Reason}
            end
    end.

check_gate(#cartwheel_state{current_phase = <<"discovery_n_analysis">>, finding_count = FC, term_count = TC})
  when FC > 0, TC > 0 ->
    ok;
check_gate(#cartwheel_state{current_phase = <<"discovery_n_analysis">>}) ->
    {error, gate_conditions_not_met};
check_gate(#cartwheel_state{current_phase = <<"architecture_n_planning">>, dossier_count = DC, spoke_count = SC, plan_approved = PA})
  when DC > 0, SC > 0, PA =:= true ->
    ok;
check_gate(#cartwheel_state{current_phase = <<"architecture_n_planning">>}) ->
    {error, gate_conditions_not_met};
check_gate(#cartwheel_state{current_phase = <<"testing_n_implementation">>, skeleton_created = SC, implemented_spoke_count = ISC, build_verified = BV})
  when SC =:= true, ISC > 0, BV =:= true ->
    ok;
check_gate(#cartwheel_state{current_phase = <<"testing_n_implementation">>}) ->
    {error, gate_conditions_not_met};
check_gate(#cartwheel_state{current_phase = <<"deployment_n_operations">>, deployment_count = DC, active_incidents = AI})
  when DC > 0, AI =:= 0 ->
    ok;
check_gate(#cartwheel_state{current_phase = <<"deployment_n_operations">>}) ->
    {error, gate_conditions_not_met};
check_gate(_State) ->
    ok.

execute_start_architecture(Payload, #cartwheel_state{current_phase = <<"architecture_n_planning">>}) ->
    {ok, Cmd} = start_architecture_v1:from_map(Payload),
    convert_events(maybe_start_architecture:handle(Cmd), fun architecture_started_v1:to_map/1);
execute_start_architecture(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_start_architecture(_Payload, _State) ->
    {error, not_in_architecture_phase}.

execute_define_dossier(Payload, #cartwheel_state{current_phase = <<"architecture_n_planning">>}) ->
    {ok, Cmd} = define_dossier_v1:from_map(Payload),
    convert_events(maybe_define_dossier:handle(Cmd), fun dossier_defined_v1:to_map/1);
execute_define_dossier(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_define_dossier(_Payload, _State) ->
    {error, not_in_architecture_phase}.

execute_inventory_spoke(Payload, #cartwheel_state{current_phase = <<"architecture_n_planning">>}) ->
    {ok, Cmd} = inventory_spoke_v1:from_map(Payload),
    convert_events(maybe_inventory_spoke:handle(Cmd), fun spoke_inventoried_v1:to_map/1);
execute_inventory_spoke(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_inventory_spoke(_Payload, _State) ->
    {error, not_in_architecture_phase}.

execute_draft_plan(Payload, #cartwheel_state{current_phase = <<"architecture_n_planning">>}) ->
    {ok, Cmd} = draft_plan_v1:from_map(Payload),
    convert_events(maybe_draft_plan:handle(Cmd), fun plan_drafted_v1:to_map/1);
execute_draft_plan(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_draft_plan(_Payload, _State) ->
    {error, not_in_architecture_phase}.

execute_approve_plan(Payload, #cartwheel_state{current_phase = <<"architecture_n_planning">>}) ->
    {ok, Cmd} = approve_plan_v1:from_map(Payload),
    convert_events(maybe_approve_plan:handle(Cmd), fun plan_approved_v1:to_map/1);
execute_approve_plan(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_approve_plan(_Payload, _State) ->
    {error, not_in_architecture_phase}.

execute_complete_architecture(Payload, #cartwheel_state{current_phase = <<"architecture_n_planning">>, dossier_count = DC, spoke_count = SC, plan_approved = PA})
  when DC > 0, SC > 0, PA =:= true ->
    {ok, Cmd} = complete_architecture_v1:from_map(Payload),
    convert_events(maybe_complete_architecture:handle(Cmd), fun architecture_completed_v1:to_map/1);
execute_complete_architecture(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_complete_architecture(_Payload, #cartwheel_state{current_phase = Phase}) when Phase =/= <<"architecture_n_planning">> ->
    {error, not_in_architecture_phase};
execute_complete_architecture(_Payload, #cartwheel_state{dossier_count = 0}) ->
    {error, no_dossiers_defined};
execute_complete_architecture(_Payload, #cartwheel_state{spoke_count = 0}) ->
    {error, no_spokes_inventoried};
execute_complete_architecture(_Payload, #cartwheel_state{plan_approved = false}) ->
    {error, plan_not_approved}.

execute_start_testing(Payload, #cartwheel_state{current_phase = <<"testing_n_implementation">>}) ->
    {ok, Cmd} = start_testing_v1:from_map(Payload),
    convert_events(maybe_start_testing:handle(Cmd), fun testing_started_v1:to_map/1);
execute_start_testing(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_start_testing(_Payload, _State) ->
    {error, not_in_testing_phase}.

execute_create_skeleton(Payload, #cartwheel_state{current_phase = <<"testing_n_implementation">>}) ->
    {ok, Cmd} = create_skeleton_v1:from_map(Payload),
    convert_events(maybe_create_skeleton:handle(Cmd), fun skeleton_created_v1:to_map/1);
execute_create_skeleton(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_create_skeleton(_Payload, _State) ->
    {error, not_in_testing_phase}.

execute_implement_spoke(Payload, #cartwheel_state{current_phase = <<"testing_n_implementation">>}) ->
    {ok, Cmd} = implement_spoke_v1:from_map(Payload),
    convert_events(maybe_implement_spoke:handle(Cmd), fun spoke_implemented_v1:to_map/1);
execute_implement_spoke(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_implement_spoke(_Payload, _State) ->
    {error, not_in_testing_phase}.

execute_verify_build(Payload, #cartwheel_state{current_phase = <<"testing_n_implementation">>}) ->
    {ok, Cmd} = verify_build_v1:from_map(Payload),
    convert_events(maybe_verify_build:handle(Cmd), fun build_verified_v1:to_map/1);
execute_verify_build(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_verify_build(_Payload, _State) ->
    {error, not_in_testing_phase}.

execute_complete_testing(Payload, #cartwheel_state{current_phase = <<"testing_n_implementation">>, skeleton_created = SC, implemented_spoke_count = ISC, build_verified = BV})
  when SC =:= true, ISC > 0, BV =:= true ->
    {ok, Cmd} = complete_testing_v1:from_map(Payload),
    convert_events(maybe_complete_testing:handle(Cmd), fun testing_completed_v1:to_map/1);
execute_complete_testing(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_complete_testing(_Payload, #cartwheel_state{current_phase = Phase}) when Phase =/= <<"testing_n_implementation">> ->
    {error, not_in_testing_phase};
execute_complete_testing(_Payload, #cartwheel_state{skeleton_created = false}) ->
    {error, skeleton_not_created};
execute_complete_testing(_Payload, #cartwheel_state{implemented_spoke_count = 0}) ->
    {error, no_spokes_implemented};
execute_complete_testing(_Payload, #cartwheel_state{build_verified = false}) ->
    {error, build_not_verified}.

execute_start_deployment(Payload, #cartwheel_state{current_phase = <<"deployment_n_operations">>}) ->
    {ok, Cmd} = start_deployment_v1:from_map(Payload),
    convert_events(maybe_start_deployment:handle(Cmd), fun deployment_started_v1:to_map/1);
execute_start_deployment(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_start_deployment(_Payload, _State) ->
    {error, not_in_deployment_phase}.

execute_record_deployment(Payload, #cartwheel_state{current_phase = <<"deployment_n_operations">>}) ->
    {ok, Cmd} = record_deployment_v1:from_map(Payload),
    convert_events(maybe_record_deployment:handle(Cmd), fun deployment_recorded_v1:to_map/1);
execute_record_deployment(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_record_deployment(_Payload, _State) ->
    {error, not_in_deployment_phase}.

execute_report_incident(Payload, #cartwheel_state{current_phase = <<"deployment_n_operations">>}) ->
    {ok, Cmd} = report_incident_v1:from_map(Payload),
    convert_events(maybe_report_incident:handle(Cmd), fun incident_reported_v1:to_map/1);
execute_report_incident(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_report_incident(_Payload, _State) ->
    {error, not_in_deployment_phase}.

execute_resolve_incident(Payload, #cartwheel_state{current_phase = <<"deployment_n_operations">>}) ->
    {ok, Cmd} = resolve_incident_v1:from_map(Payload),
    convert_events(maybe_resolve_incident:handle(Cmd), fun incident_resolved_v1:to_map/1);
execute_resolve_incident(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_resolve_incident(_Payload, _State) ->
    {error, not_in_deployment_phase}.

execute_complete_deployment(Payload, #cartwheel_state{current_phase = <<"deployment_n_operations">>, deployment_count = DC, active_incidents = AI})
  when DC > 0, AI =:= 0 ->
    {ok, Cmd} = complete_deployment_v1:from_map(Payload),
    convert_events(maybe_complete_deployment:handle(Cmd), fun deployment_completed_v1:to_map/1);
execute_complete_deployment(_Payload, #cartwheel_state{cartwheel_id = undefined}) ->
    {error, cartwheel_not_found};
execute_complete_deployment(_Payload, #cartwheel_state{current_phase = Phase}) when Phase =/= <<"deployment_n_operations">> ->
    {error, not_in_deployment_phase};
execute_complete_deployment(_Payload, #cartwheel_state{deployment_count = 0}) ->
    {error, no_deployments_recorded};
execute_complete_deployment(_Payload, #cartwheel_state{active_incidents = AI}) when AI > 0 ->
    {error, active_incidents_exist}.

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

%% @doc Apply event to state (event sourcing)
-spec apply_event(map(), state()) -> state().
apply_event(#{event_type := <<"cartwheel_initiated_v1">>} = E, State) ->
    State#cartwheel_state{
        cartwheel_id = maps:get(cartwheel_id, E),
        torch_id = maps:get(torch_id, E, undefined),
        context_name = maps:get(context_name, E, maps:get(name, E, undefined)),
        current_phase = <<"discovery_n_analysis">>,
        status = ?INITIATED bor ?DISCOVERY_ACTIVE,
        initiated_at = maps:get(initiated_at, E)
    };
apply_event(#{event_type := <<"discovery_started_v1">>} = E, State) ->
    State#cartwheel_state{
        phase_started_at = maps:get(started_at, E)
    };
apply_event(#{event_type := <<"finding_recorded_v1">>} = _E, State) ->
    State#cartwheel_state{
        finding_count = State#cartwheel_state.finding_count + 1
    };
apply_event(#{event_type := <<"term_defined_v1">>} = _E, State) ->
    State#cartwheel_state{
        term_count = State#cartwheel_state.term_count + 1
    };
apply_event(#{event_type := <<"discovery_completed_v1">>} = _E, State) ->
    State#cartwheel_state{
        status = State#cartwheel_state.status bor ?DISCOVERY_COMPLETE
    };
apply_event(#{event_type := <<"phase_transitioned_v1">>} = E, State) ->
    ToPhase = maps:get(to_phase, E),
    StatusFlag = phase_to_active_flag(ToPhase),
    State#cartwheel_state{
        current_phase = ToPhase,
        status = State#cartwheel_state.status bor StatusFlag,
        phase_started_at = maps:get(transitioned_at, E)
    };
apply_event(#{event_type := <<"architecture_started_v1">>} = E, State) ->
    State#cartwheel_state{
        phase_started_at = maps:get(started_at, E)
    };
apply_event(#{event_type := <<"dossier_defined_v1">>} = _E, State) ->
    State#cartwheel_state{
        dossier_count = State#cartwheel_state.dossier_count + 1
    };
apply_event(#{event_type := <<"spoke_inventoried_v1">>} = _E, State) ->
    State#cartwheel_state{
        spoke_count = State#cartwheel_state.spoke_count + 1
    };
apply_event(#{event_type := <<"plan_drafted_v1">>} = _E, State) ->
    State;
apply_event(#{event_type := <<"plan_approved_v1">>} = _E, State) ->
    State#cartwheel_state{
        plan_approved = true
    };
apply_event(#{event_type := <<"architecture_completed_v1">>} = _E, State) ->
    State#cartwheel_state{
        status = State#cartwheel_state.status bor ?ARCHITECTURE_COMPLETE
    };
apply_event(#{event_type := <<"testing_started_v1">>} = E, State) ->
    State#cartwheel_state{
        phase_started_at = maps:get(started_at, E)
    };
apply_event(#{event_type := <<"skeleton_created_v1">>} = _E, State) ->
    State#cartwheel_state{
        skeleton_created = true
    };
apply_event(#{event_type := <<"spoke_implemented_v1">>} = _E, State) ->
    State#cartwheel_state{
        implemented_spoke_count = State#cartwheel_state.implemented_spoke_count + 1
    };
apply_event(#{event_type := <<"build_verified_v1">>} = _E, State) ->
    State#cartwheel_state{
        build_verified = true
    };
apply_event(#{event_type := <<"testing_completed_v1">>} = _E, State) ->
    State#cartwheel_state{
        status = State#cartwheel_state.status bor ?TESTING_COMPLETE
    };
apply_event(#{event_type := <<"deployment_started_v1">>} = E, State) ->
    State#cartwheel_state{
        phase_started_at = maps:get(started_at, E)
    };
apply_event(#{event_type := <<"deployment_recorded_v1">>} = _E, State) ->
    State#cartwheel_state{
        deployment_count = State#cartwheel_state.deployment_count + 1
    };
apply_event(#{event_type := <<"incident_reported_v1">>} = _E, State) ->
    State#cartwheel_state{
        active_incidents = State#cartwheel_state.active_incidents + 1
    };
apply_event(#{event_type := <<"incident_resolved_v1">>} = _E, State) ->
    State#cartwheel_state{
        active_incidents = max(0, State#cartwheel_state.active_incidents - 1)
    };
apply_event(#{event_type := <<"deployment_completed_v1">>} = _E, State) ->
    State#cartwheel_state{
        status = State#cartwheel_state.status bor ?DEPLOYMENT_COMPLETE,
        completed_at = erlang:system_time(millisecond)
    };
apply_event(_E, State) ->
    State.

phase_to_active_flag(<<"discovery_n_analysis">>) -> ?DISCOVERY_ACTIVE;
phase_to_active_flag(<<"architecture_n_planning">>) -> ?ARCHITECTURE_ACTIVE;
phase_to_active_flag(<<"testing_n_implementation">>) -> ?TESTING_ACTIVE;
phase_to_active_flag(<<"deployment_n_operations">>) -> ?DEPLOYMENT_ACTIVE;
phase_to_active_flag(_) -> 0.
