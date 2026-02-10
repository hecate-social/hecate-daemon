%%% @doc Aggregate for the monitoring process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands: register_health_check (only when active),
%%%                  record_health_status (only when active),
%%%                  raise_incident (only when active)
%%% Stream: monitoring-{division_id}
%%% @end
-module(monitoring_aggregate).

-behaviour(evoq_aggregate).

-include_lib("monitor_division/include/monitoring_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(monitoring_state, {
    division_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    health_checks = #{} :: #{binary() => map()},
    incidents = #{} :: #{binary() => map()},
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #monitoring_state{}}.

%% --- Execute: lifecycle commands ---

%% Start monitoring (only on fresh aggregate)
execute(#monitoring_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_monitoring">> -> execute_start_monitoring(Payload);
        _ -> {error, monitoring_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#monitoring_state{status = S} = State, Payload)
  when S band ?MONITORING_ARCHIVED =:= 0, S band ?MONITORING_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_monitoring">> -> execute_archive_monitoring(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#monitoring_state{status = S}, _Payload)
  when S band ?MONITORING_ARCHIVED =/= 0 ->
    {error, monitoring_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"register_health_check">>, Payload, #monitoring_state{status = S} = State)
  when S band ?MONITORING_ACTIVE =/= 0 ->
    execute_register_health_check(Payload, State);
execute_lifecycle(<<"register_health_check">>, _Payload, #monitoring_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"record_health_status">>, Payload, #monitoring_state{status = S} = State)
  when S band ?MONITORING_ACTIVE =/= 0 ->
    execute_record_health_status(Payload, State);
execute_lifecycle(<<"record_health_status">>, _Payload, #monitoring_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"raise_incident">>, Payload, #monitoring_state{status = S} = State)
  when S band ?MONITORING_ACTIVE =/= 0 ->
    execute_raise_incident(Payload, State);
execute_lifecycle(<<"raise_incident">>, _Payload, #monitoring_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_monitoring">>, Payload, #monitoring_state{status = S} = State)
  when S band ?MONITORING_ACTIVE =/= 0 ->
    execute_pause_monitoring(Payload, State);
execute_lifecycle(<<"pause_monitoring">>, _Payload, #monitoring_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_monitoring">>, Payload, #monitoring_state{status = S} = State)
  when S band ?MONITORING_PAUSED =/= 0 ->
    execute_resume_monitoring(Payload, State);
execute_lifecycle(<<"resume_monitoring">>, _Payload, #monitoring_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_monitoring">>, Payload, #monitoring_state{status = S} = State)
  when S band ?MONITORING_ACTIVE =/= 0 ->
    execute_complete_monitoring(Payload, State);
execute_lifecycle(<<"complete_monitoring">>, _Payload, #monitoring_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_monitoring(Payload) ->
    {ok, Cmd} = start_monitoring_v1:from_map(Payload),
    convert_events(maybe_start_monitoring:handle(Cmd), fun monitoring_started_v1:to_map/1).

execute_register_health_check(Payload, #monitoring_state{health_checks = Checks}) ->
    {ok, Cmd} = register_health_check_v1:from_map(Payload),
    Context = #{health_checks => Checks},
    convert_events(maybe_register_health_check:handle(Cmd, Context), fun health_check_registered_v1:to_map/1).

execute_record_health_status(Payload, #monitoring_state{health_checks = Checks}) ->
    {ok, Cmd} = record_health_status_v1:from_map(Payload),
    Context = #{health_checks => Checks},
    convert_events(maybe_record_health_status:handle(Cmd, Context), fun health_status_recorded_v1:to_map/1).

execute_raise_incident(Payload, #monitoring_state{incidents = Incidents}) ->
    {ok, Cmd} = raise_incident_v1:from_map(Payload),
    Context = #{incidents => Incidents},
    convert_events(maybe_raise_incident:handle(Cmd, Context), fun incident_raised_v1:to_map/1).

execute_pause_monitoring(Payload, _State) ->
    {ok, Cmd} = pause_monitoring_v1:from_map(Payload),
    convert_events(maybe_pause_monitoring:handle(Cmd), fun monitoring_paused_v1:to_map/1).

execute_resume_monitoring(Payload, _State) ->
    {ok, Cmd} = resume_monitoring_v1:from_map(Payload),
    convert_events(maybe_resume_monitoring:handle(Cmd), fun monitoring_resumed_v1:to_map/1).

execute_complete_monitoring(Payload, _State) ->
    {ok, Cmd} = complete_monitoring_v1:from_map(Payload),
    convert_events(maybe_complete_monitoring:handle(Cmd), fun monitoring_completed_v1:to_map/1).

execute_archive_monitoring(Payload, _State) ->
    {ok, Cmd} = archive_monitoring_v1:from_map(Payload),
    convert_events(maybe_archive_monitoring:handle(Cmd), fun monitoring_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"monitoring_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"monitoring_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"health_check_registered_v1">>} = E) ->
    apply_health_check_registered(E, State);
apply(State, #{event_type := <<"health_check_registered_v1">>} = E) ->
    apply_health_check_registered(E, State);

apply(State, #{<<"event_type">> := <<"health_status_recorded_v1">>} = E) ->
    apply_health_status_recorded(E, State);
apply(State, #{event_type := <<"health_status_recorded_v1">>} = E) ->
    apply_health_status_recorded(E, State);

apply(State, #{<<"event_type">> := <<"incident_raised_v1">>} = E) ->
    apply_incident_raised(E, State);
apply(State, #{event_type := <<"incident_raised_v1">>} = E) ->
    apply_incident_raised(E, State);

apply(State, #{<<"event_type">> := <<"monitoring_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"monitoring_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"monitoring_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"monitoring_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"monitoring_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"monitoring_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"monitoring_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"monitoring_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?MONITORING_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?MONITORING_ACTIVE),
    State#monitoring_state{
        division_id = get_value(division_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_health_check_registered(E, State) ->
    CheckId = get_value(check_id, E),
    Details = #{
        check_id => CheckId,
        check_name => get_value(check_name, E),
        check_type => get_value(check_type, E),
        endpoint => get_value(endpoint, E),
        interval_ms => get_value(interval_ms, E),
        registered_at => get_value(registered_at, E)
    },
    Checks = State#monitoring_state.health_checks,
    State#monitoring_state{
        health_checks = Checks#{CheckId => Details}
    }.

apply_health_status_recorded(E, State) ->
    CheckId = get_value(check_id, E),
    Checks = State#monitoring_state.health_checks,
    ExistingCheck = maps:get(CheckId, Checks, #{}),
    UpdatedCheck = ExistingCheck#{
        last_status => get_value(status, E),
        last_latency_ms => get_value(latency_ms, E),
        last_recorded_at => get_value(recorded_at, E)
    },
    State#monitoring_state{
        health_checks = Checks#{CheckId => UpdatedCheck}
    }.

apply_incident_raised(E, State) ->
    IncidentId = get_value(incident_id, E),
    Details = #{
        incident_id => IncidentId,
        incident_title => get_value(incident_title, E),
        severity => get_value(severity, E),
        description => get_value(description, E),
        raised_at => get_value(raised_at, E)
    },
    Incidents = State#monitoring_state.incidents,
    State#monitoring_state{
        incidents = Incidents#{IncidentId => Details}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#monitoring_state.status, ?MONITORING_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?MONITORING_PAUSED),
    State#monitoring_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#monitoring_state.status, ?MONITORING_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?MONITORING_ACTIVE),
    State#monitoring_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#monitoring_state.status, ?MONITORING_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?MONITORING_COMPLETED),
    State#monitoring_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#monitoring_state{
        status = evoq_bit_flags:set(State#monitoring_state.status, ?MONITORING_ARCHIVED)
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
