%%% @doc Aggregate for the design process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands: design_aggregate (only when active),
%%%                  design_event (only when active)
%%% Stream: design-{division_id}
%%% @end
-module(design_aggregate).

-behaviour(evoq_aggregate).

-include_lib("design_division/include/design_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(design_state, {
    division_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    designed_aggregates = #{} :: #{binary() => map()},  %% name => details
    designed_events = #{} :: #{binary() => map()},      %% name => details
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #design_state{}}.

%% --- Execute: lifecycle commands ---

%% Start design (only on fresh aggregate)
execute(#design_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_design">> -> execute_start_design(Payload);
        _ -> {error, design_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#design_state{status = S} = State, Payload)
  when S band ?DESIGN_ARCHIVED =:= 0, S band ?DESIGN_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_design">> -> execute_archive_design(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#design_state{status = S}, _Payload)
  when S band ?DESIGN_ARCHIVED =/= 0 ->
    {error, design_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"design_aggregate">>, Payload, #design_state{status = S} = State)
  when S band ?DESIGN_ACTIVE =/= 0 ->
    execute_design_aggregate(Payload, State);
execute_lifecycle(<<"design_aggregate">>, _Payload, #design_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"design_event">>, Payload, #design_state{status = S} = State)
  when S band ?DESIGN_ACTIVE =/= 0 ->
    execute_design_event(Payload, State);
execute_lifecycle(<<"design_event">>, _Payload, #design_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_design">>, Payload, #design_state{status = S} = State)
  when S band ?DESIGN_ACTIVE =/= 0 ->
    execute_pause_design(Payload, State);
execute_lifecycle(<<"pause_design">>, _Payload, #design_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_design">>, Payload, #design_state{status = S} = State)
  when S band ?DESIGN_PAUSED =/= 0 ->
    execute_resume_design(Payload, State);
execute_lifecycle(<<"resume_design">>, _Payload, #design_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_design">>, Payload, #design_state{status = S} = State)
  when S band ?DESIGN_ACTIVE =/= 0 ->
    execute_complete_design(Payload, State);
execute_lifecycle(<<"complete_design">>, _Payload, #design_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_design(Payload) ->
    {ok, Cmd} = start_design_v1:from_map(Payload),
    convert_events(maybe_start_design:handle(Cmd), fun design_started_v1:to_map/1).

execute_design_aggregate(Payload, #design_state{designed_aggregates = Aggregates}) ->
    {ok, Cmd} = design_aggregate_v1:from_map(Payload),
    Context = #{designed_aggregates => Aggregates},
    convert_events(maybe_design_aggregate:handle(Cmd, Context), fun aggregate_designed_v1:to_map/1).

execute_design_event(Payload, #design_state{designed_events = Events}) ->
    {ok, Cmd} = design_event_v1:from_map(Payload),
    Context = #{designed_events => Events},
    convert_events(maybe_design_event:handle(Cmd, Context), fun event_designed_v1:to_map/1).

execute_pause_design(Payload, _State) ->
    {ok, Cmd} = pause_design_v1:from_map(Payload),
    convert_events(maybe_pause_design:handle(Cmd), fun design_paused_v1:to_map/1).

execute_resume_design(Payload, _State) ->
    {ok, Cmd} = resume_design_v1:from_map(Payload),
    convert_events(maybe_resume_design:handle(Cmd), fun design_resumed_v1:to_map/1).

execute_complete_design(Payload, _State) ->
    {ok, Cmd} = complete_design_v1:from_map(Payload),
    convert_events(maybe_complete_design:handle(Cmd), fun design_completed_v1:to_map/1).

execute_archive_design(Payload, _State) ->
    {ok, Cmd} = archive_design_v1:from_map(Payload),
    convert_events(maybe_archive_design:handle(Cmd), fun design_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"design_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"design_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"aggregate_designed_v1">>} = E) ->
    apply_aggregate_designed(E, State);
apply(State, #{event_type := <<"aggregate_designed_v1">>} = E) ->
    apply_aggregate_designed(E, State);

apply(State, #{<<"event_type">> := <<"event_designed_v1">>} = E) ->
    apply_event_designed(E, State);
apply(State, #{event_type := <<"event_designed_v1">>} = E) ->
    apply_event_designed(E, State);

apply(State, #{<<"event_type">> := <<"design_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"design_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"design_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"design_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"design_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"design_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"design_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"design_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?DESIGN_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?DESIGN_ACTIVE),
    State#design_state{
        division_id = get_value(division_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_aggregate_designed(E, State) ->
    AggregateName = get_value(aggregate_name, E),
    Details = #{
        aggregate_name => AggregateName,
        description => get_value(description, E),
        stream_prefix => get_value(stream_prefix, E),
        fields => get_value(fields, E)
    },
    Aggregates = State#design_state.designed_aggregates,
    State#design_state{
        designed_aggregates = Aggregates#{AggregateName => Details}
    }.

apply_event_designed(E, State) ->
    EventName = get_value(event_name, E),
    Details = #{
        event_name => EventName,
        description => get_value(description, E),
        aggregate_name => get_value(aggregate_name, E),
        fields => get_value(fields, E)
    },
    Events = State#design_state.designed_events,
    State#design_state{
        designed_events = Events#{EventName => Details}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#design_state.status, ?DESIGN_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?DESIGN_PAUSED),
    State#design_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#design_state.status, ?DESIGN_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?DESIGN_ACTIVE),
    State#design_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#design_state.status, ?DESIGN_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?DESIGN_COMPLETED),
    State#design_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#design_state{
        status = evoq_bit_flags:set(State#design_state.status, ?DESIGN_ARCHIVED)
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
