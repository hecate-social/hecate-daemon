%%% @doc Aggregate for the discovery process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain command: discover_division (only when active)
%%% @end
-module(discovery_aggregate).

-behaviour(evoq_aggregate).

-include_lib("discover_divisions/include/discovery_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(discovery_state, {
    venture_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    discovered_divisions = #{} :: #{binary() => binary()},
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #discovery_state{}}.

%% --- Execute: lifecycle commands ---

%% Start discovery (only on fresh aggregate)
execute(#discovery_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_discovery">> -> execute_start_discovery(Payload);
        _ -> {error, discovery_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#discovery_state{status = S} = State, Payload)
  when S band ?DISCOVERY_ARCHIVED =:= 0, S band ?DISCOVERY_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_discovery">> -> execute_archive_discovery(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#discovery_state{status = S}, _Payload)
  when S band ?DISCOVERY_ARCHIVED =/= 0 ->
    {error, discovery_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"discover_division">>, Payload, #discovery_state{status = S} = State)
  when S band ?DISCOVERY_ACTIVE =/= 0 ->
    execute_discover_division(Payload, State);
execute_lifecycle(<<"discover_division">>, _Payload, #discovery_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_discovery">>, Payload, #discovery_state{status = S} = State)
  when S band ?DISCOVERY_ACTIVE =/= 0 ->
    execute_pause_discovery(Payload, State);
execute_lifecycle(<<"pause_discovery">>, _Payload, #discovery_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_discovery">>, Payload, #discovery_state{status = S} = State)
  when S band ?DISCOVERY_PAUSED =/= 0 ->
    execute_resume_discovery(Payload, State);
execute_lifecycle(<<"resume_discovery">>, _Payload, #discovery_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_discovery">>, Payload, #discovery_state{status = S} = State)
  when S band ?DISCOVERY_ACTIVE =/= 0 ->
    execute_complete_discovery(Payload, State);
execute_lifecycle(<<"complete_discovery">>, _Payload, #discovery_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_discovery(Payload) ->
    {ok, Cmd} = start_discovery_v1:from_map(Payload),
    convert_events(maybe_start_discovery:handle(Cmd), fun discovery_started_v1:to_map/1).

execute_discover_division(Payload, #discovery_state{discovered_divisions = Discovered}) ->
    {ok, Cmd} = discover_division_v1:from_map(Payload),
    Context = #{discovered_divisions => Discovered},
    convert_events(maybe_discover_division:handle(Cmd, Context), fun division_discovered_v1:to_map/1).

execute_pause_discovery(Payload, _State) ->
    {ok, Cmd} = pause_discovery_v1:from_map(Payload),
    convert_events(maybe_pause_discovery:handle(Cmd), fun discovery_paused_v1:to_map/1).

execute_resume_discovery(Payload, _State) ->
    {ok, Cmd} = resume_discovery_v1:from_map(Payload),
    convert_events(maybe_resume_discovery:handle(Cmd), fun discovery_resumed_v1:to_map/1).

execute_complete_discovery(Payload, _State) ->
    {ok, Cmd} = complete_discovery_v1:from_map(Payload),
    convert_events(maybe_complete_discovery:handle(Cmd), fun discovery_completed_v1:to_map/1).

execute_archive_discovery(Payload, _State) ->
    {ok, Cmd} = archive_discovery_v1:from_map(Payload),
    convert_events(maybe_archive_discovery:handle(Cmd), fun discovery_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"discovery_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"discovery_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"division_discovered_v1">>} = E) ->
    apply_division_discovered(E, State);
apply(State, #{event_type := <<"division_discovered_v1">>} = E) ->
    apply_division_discovered(E, State);

apply(State, #{<<"event_type">> := <<"discovery_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"discovery_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"discovery_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"discovery_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"discovery_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"discovery_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"discovery_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"discovery_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?DISCOVERY_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?DISCOVERY_ACTIVE),
    State#discovery_state{
        venture_id = get_value(venture_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_division_discovered(E, State) ->
    DivisionId = get_value(division_id, E),
    ContextName = get_value(context_name, E),
    Discovered = State#discovery_state.discovered_divisions,
    State#discovery_state{
        discovered_divisions = Discovered#{ContextName => DivisionId}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#discovery_state.status, ?DISCOVERY_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?DISCOVERY_PAUSED),
    State#discovery_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#discovery_state.status, ?DISCOVERY_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?DISCOVERY_ACTIVE),
    State#discovery_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#discovery_state.status, ?DISCOVERY_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?DISCOVERY_COMPLETED),
    State#discovery_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#discovery_state{
        status = evoq_bit_flags:set(State#discovery_state.status, ?DISCOVERY_ARCHIVED)
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
