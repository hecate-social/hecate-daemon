%%% @doc Aggregate for the plan process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands: plan_desk (only when active),
%%%                  plan_dependency (only when active)
%%% Stream: plan-{division_id}
%%% @end
-module(plan_aggregate).

-behaviour(evoq_aggregate).

-include_lib("plan_division/include/plan_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(plan_state, {
    division_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    planned_desks = #{} :: #{binary() => map()},
    planned_dependencies = #{} :: #{binary() => map()},
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #plan_state{}}.

%% --- Execute: lifecycle commands ---

%% Start plan (only on fresh aggregate)
execute(#plan_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_plan">> -> execute_start_plan(Payload);
        _ -> {error, plan_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#plan_state{status = S} = State, Payload)
  when S band ?PLAN_ARCHIVED =:= 0, S band ?PLAN_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_plan">> -> execute_archive_plan(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#plan_state{status = S}, _Payload)
  when S band ?PLAN_ARCHIVED =/= 0 ->
    {error, plan_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"plan_desk">>, Payload, #plan_state{status = S} = State)
  when S band ?PLAN_ACTIVE =/= 0 ->
    execute_plan_desk(Payload, State);
execute_lifecycle(<<"plan_desk">>, _Payload, #plan_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"plan_dependency">>, Payload, #plan_state{status = S} = State)
  when S band ?PLAN_ACTIVE =/= 0 ->
    execute_plan_dependency(Payload, State);
execute_lifecycle(<<"plan_dependency">>, _Payload, #plan_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_plan">>, Payload, #plan_state{status = S} = State)
  when S band ?PLAN_ACTIVE =/= 0 ->
    execute_pause_plan(Payload, State);
execute_lifecycle(<<"pause_plan">>, _Payload, #plan_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_plan">>, Payload, #plan_state{status = S} = State)
  when S band ?PLAN_PAUSED =/= 0 ->
    execute_resume_plan(Payload, State);
execute_lifecycle(<<"resume_plan">>, _Payload, #plan_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_plan">>, Payload, #plan_state{status = S} = State)
  when S band ?PLAN_ACTIVE =/= 0 ->
    execute_complete_plan(Payload, State);
execute_lifecycle(<<"complete_plan">>, _Payload, #plan_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_plan(Payload) ->
    {ok, Cmd} = start_plan_v1:from_map(Payload),
    convert_events(maybe_start_plan:handle(Cmd), fun plan_started_v1:to_map/1).

execute_plan_desk(Payload, #plan_state{planned_desks = Desks}) ->
    {ok, Cmd} = plan_desk_v1:from_map(Payload),
    Context = #{planned_desks => Desks},
    convert_events(maybe_plan_desk:handle(Cmd, Context), fun desk_planned_v1:to_map/1).

execute_plan_dependency(Payload, #plan_state{planned_dependencies = Deps}) ->
    {ok, Cmd} = plan_dependency_v1:from_map(Payload),
    Context = #{planned_dependencies => Deps},
    convert_events(maybe_plan_dependency:handle(Cmd, Context), fun dependency_planned_v1:to_map/1).

execute_pause_plan(Payload, _State) ->
    {ok, Cmd} = pause_plan_v1:from_map(Payload),
    convert_events(maybe_pause_plan:handle(Cmd), fun plan_paused_v1:to_map/1).

execute_resume_plan(Payload, _State) ->
    {ok, Cmd} = resume_plan_v1:from_map(Payload),
    convert_events(maybe_resume_plan:handle(Cmd), fun plan_resumed_v1:to_map/1).

execute_complete_plan(Payload, _State) ->
    {ok, Cmd} = complete_plan_v1:from_map(Payload),
    convert_events(maybe_complete_plan:handle(Cmd), fun plan_completed_v1:to_map/1).

execute_archive_plan(Payload, _State) ->
    {ok, Cmd} = archive_plan_v1:from_map(Payload),
    convert_events(maybe_archive_plan:handle(Cmd), fun plan_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"plan_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"plan_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"desk_planned_v1">>} = E) ->
    apply_desk_planned(E, State);
apply(State, #{event_type := <<"desk_planned_v1">>} = E) ->
    apply_desk_planned(E, State);

apply(State, #{<<"event_type">> := <<"dependency_planned_v1">>} = E) ->
    apply_dependency_planned(E, State);
apply(State, #{event_type := <<"dependency_planned_v1">>} = E) ->
    apply_dependency_planned(E, State);

apply(State, #{<<"event_type">> := <<"plan_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"plan_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"plan_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"plan_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"plan_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"plan_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"plan_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"plan_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?PLAN_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?PLAN_ACTIVE),
    State#plan_state{
        division_id = get_value(division_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_desk_planned(E, State) ->
    DeskName = get_value(desk_name, E),
    Details = #{
        desk_name => DeskName,
        description => get_value(description, E),
        department => get_value(department, E),
        estimated_effort => get_value(estimated_effort, E)
    },
    Desks = State#plan_state.planned_desks,
    State#plan_state{
        planned_desks = Desks#{DeskName => Details}
    }.

apply_dependency_planned(E, State) ->
    DependencyId = get_value(dependency_id, E),
    Details = #{
        dependency_id => DependencyId,
        from_desk => get_value(from_desk, E),
        to_desk => get_value(to_desk, E),
        dependency_type => get_value(dependency_type, E)
    },
    Deps = State#plan_state.planned_dependencies,
    State#plan_state{
        planned_dependencies = Deps#{DependencyId => Details}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#plan_state.status, ?PLAN_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?PLAN_PAUSED),
    State#plan_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#plan_state.status, ?PLAN_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?PLAN_ACTIVE),
    State#plan_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#plan_state.status, ?PLAN_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?PLAN_COMPLETED),
    State#plan_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#plan_state{
        status = evoq_bit_flags:set(State#plan_state.status, ?PLAN_ARCHIVED)
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
