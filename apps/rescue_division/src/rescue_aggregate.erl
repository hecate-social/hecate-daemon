%%% @doc Aggregate for the rescue process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands: diagnose_incident (only when active),
%%%                  apply_fix (only when active)
%%% Stream: rescue-{division_id}
%%% @end
-module(rescue_aggregate).

-behaviour(evoq_aggregate).

-include_lib("rescue_division/include/rescue_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(rescue_state, {
    division_id = undefined :: binary() | undefined,
    incident_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    diagnoses = #{} :: #{binary() => map()},
    fixes = #{} :: #{binary() => map()},
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #rescue_state{}}.

%% --- Execute: lifecycle commands ---

%% Start rescue (only on fresh aggregate)
execute(#rescue_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_rescue">> -> execute_start_rescue(Payload);
        _ -> {error, rescue_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#rescue_state{status = S} = State, Payload)
  when S band ?RESCUE_ARCHIVED =:= 0, S band ?RESCUE_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_rescue">> -> execute_archive_rescue(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#rescue_state{status = S}, _Payload)
  when S band ?RESCUE_ARCHIVED =/= 0 ->
    {error, rescue_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"diagnose_incident">>, Payload, #rescue_state{status = S} = State)
  when S band ?RESCUE_ACTIVE =/= 0 ->
    execute_diagnose_incident(Payload, State);
execute_lifecycle(<<"diagnose_incident">>, _Payload, #rescue_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"apply_fix">>, Payload, #rescue_state{status = S} = State)
  when S band ?RESCUE_ACTIVE =/= 0 ->
    execute_apply_fix(Payload, State);
execute_lifecycle(<<"apply_fix">>, _Payload, #rescue_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_rescue">>, Payload, #rescue_state{status = S} = State)
  when S band ?RESCUE_ACTIVE =/= 0 ->
    execute_pause_rescue(Payload, State);
execute_lifecycle(<<"pause_rescue">>, _Payload, #rescue_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_rescue">>, Payload, #rescue_state{status = S} = State)
  when S band ?RESCUE_PAUSED =/= 0 ->
    execute_resume_rescue(Payload, State);
execute_lifecycle(<<"resume_rescue">>, _Payload, #rescue_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_rescue">>, Payload, #rescue_state{status = S} = State)
  when S band ?RESCUE_ACTIVE =/= 0 ->
    execute_complete_rescue(Payload, State);
execute_lifecycle(<<"complete_rescue">>, _Payload, #rescue_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_rescue(Payload) ->
    {ok, Cmd} = start_rescue_v1:from_map(Payload),
    convert_events(maybe_start_rescue:handle(Cmd), fun rescue_started_v1:to_map/1).

execute_diagnose_incident(Payload, #rescue_state{diagnoses = Diagnoses}) ->
    {ok, Cmd} = diagnose_incident_v1:from_map(Payload),
    Context = #{diagnoses => Diagnoses},
    convert_events(maybe_diagnose_incident:handle(Cmd, Context), fun incident_diagnosed_v1:to_map/1).

execute_apply_fix(Payload, #rescue_state{fixes = Fixes}) ->
    {ok, Cmd} = apply_fix_v1:from_map(Payload),
    Context = #{fixes => Fixes},
    convert_events(maybe_apply_fix:handle(Cmd, Context), fun fix_applied_v1:to_map/1).

execute_pause_rescue(Payload, _State) ->
    {ok, Cmd} = pause_rescue_v1:from_map(Payload),
    convert_events(maybe_pause_rescue:handle(Cmd), fun rescue_paused_v1:to_map/1).

execute_resume_rescue(Payload, _State) ->
    {ok, Cmd} = resume_rescue_v1:from_map(Payload),
    convert_events(maybe_resume_rescue:handle(Cmd), fun rescue_resumed_v1:to_map/1).

execute_complete_rescue(Payload, _State) ->
    {ok, Cmd} = complete_rescue_v1:from_map(Payload),
    convert_events(maybe_complete_rescue:handle(Cmd), fun rescue_completed_v1:to_map/1).

execute_archive_rescue(Payload, _State) ->
    {ok, Cmd} = archive_rescue_v1:from_map(Payload),
    convert_events(maybe_archive_rescue:handle(Cmd), fun rescue_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"rescue_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"rescue_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"incident_diagnosed_v1">>} = E) ->
    apply_incident_diagnosed(E, State);
apply(State, #{event_type := <<"incident_diagnosed_v1">>} = E) ->
    apply_incident_diagnosed(E, State);

apply(State, #{<<"event_type">> := <<"fix_applied_v1">>} = E) ->
    apply_fix_applied(E, State);
apply(State, #{event_type := <<"fix_applied_v1">>} = E) ->
    apply_fix_applied(E, State);

apply(State, #{<<"event_type">> := <<"rescue_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"rescue_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"rescue_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"rescue_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"rescue_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"rescue_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"rescue_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"rescue_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?RESCUE_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?RESCUE_ACTIVE),
    State#rescue_state{
        division_id = get_value(division_id, E),
        incident_id = get_value(incident_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_incident_diagnosed(E, State) ->
    DiagnosisId = get_value(diagnosis_id, E),
    Details = #{
        diagnosis_id => DiagnosisId,
        incident_id => get_value(incident_id, E),
        diagnosis => get_value(diagnosis, E),
        root_cause => get_value(root_cause, E),
        diagnosed_by => get_value(diagnosed_by, E),
        diagnosed_at => get_value(diagnosed_at, E)
    },
    Diagnoses = State#rescue_state.diagnoses,
    State#rescue_state{
        diagnoses = Diagnoses#{DiagnosisId => Details}
    }.

apply_fix_applied(E, State) ->
    FixId = get_value(fix_id, E),
    Details = #{
        fix_id => FixId,
        incident_id => get_value(incident_id, E),
        diagnosis_id => get_value(diagnosis_id, E),
        fix_description => get_value(fix_description, E),
        fix_type => get_value(fix_type, E),
        applied_by => get_value(applied_by, E),
        applied_at => get_value(applied_at, E)
    },
    Fixes = State#rescue_state.fixes,
    State#rescue_state{
        fixes = Fixes#{FixId => Details}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#rescue_state.status, ?RESCUE_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?RESCUE_PAUSED),
    State#rescue_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#rescue_state.status, ?RESCUE_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?RESCUE_ACTIVE),
    State#rescue_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#rescue_state.status, ?RESCUE_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?RESCUE_COMPLETED),
    State#rescue_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#rescue_state{
        status = evoq_bit_flags:set(State#rescue_state.status, ?RESCUE_ARCHIVED)
    }.

%% --- Internal ---

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key),
            maps:get(BinKey, Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
