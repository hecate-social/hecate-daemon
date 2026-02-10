%%% @doc Aggregate for the generation process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands: generate_module (only when active),
%%%                  generate_test (only when active)
%%% Stream: generation-{division_id}
%%% @end
-module(generation_aggregate).

-behaviour(evoq_aggregate).

-include_lib("generate_division/include/generation_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(generation_state, {
    division_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    generated_modules = #{} :: #{binary() => map()},
    generated_tests = #{} :: #{binary() => map()},
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #generation_state{}}.

%% --- Execute: lifecycle commands ---

%% Start generation (only on fresh aggregate)
execute(#generation_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_generation">> -> execute_start_generation(Payload);
        _ -> {error, generation_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#generation_state{status = S} = State, Payload)
  when S band ?GENERATION_ARCHIVED =:= 0, S band ?GENERATION_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_generation">> -> execute_archive_generation(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#generation_state{status = S}, _Payload)
  when S band ?GENERATION_ARCHIVED =/= 0 ->
    {error, generation_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"generate_module">>, Payload, #generation_state{status = S} = State)
  when S band ?GENERATION_ACTIVE =/= 0 ->
    execute_generate_module(Payload, State);
execute_lifecycle(<<"generate_module">>, _Payload, #generation_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"generate_test">>, Payload, #generation_state{status = S} = State)
  when S band ?GENERATION_ACTIVE =/= 0 ->
    execute_generate_test(Payload, State);
execute_lifecycle(<<"generate_test">>, _Payload, #generation_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_generation">>, Payload, #generation_state{status = S} = State)
  when S band ?GENERATION_ACTIVE =/= 0 ->
    execute_pause_generation(Payload, State);
execute_lifecycle(<<"pause_generation">>, _Payload, #generation_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_generation">>, Payload, #generation_state{status = S} = State)
  when S band ?GENERATION_PAUSED =/= 0 ->
    execute_resume_generation(Payload, State);
execute_lifecycle(<<"resume_generation">>, _Payload, #generation_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_generation">>, Payload, #generation_state{status = S} = State)
  when S band ?GENERATION_ACTIVE =/= 0 ->
    execute_complete_generation(Payload, State);
execute_lifecycle(<<"complete_generation">>, _Payload, #generation_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_generation(Payload) ->
    {ok, Cmd} = start_generation_v1:from_map(Payload),
    convert_events(maybe_start_generation:handle(Cmd), fun generation_started_v1:to_map/1).

execute_generate_module(Payload, #generation_state{generated_modules = Modules}) ->
    {ok, Cmd} = generate_module_v1:from_map(Payload),
    Context = #{generated_modules => Modules},
    convert_events(maybe_generate_module:handle(Cmd, Context), fun module_generated_v1:to_map/1).

execute_generate_test(Payload, #generation_state{generated_tests = Tests}) ->
    {ok, Cmd} = generate_test_v1:from_map(Payload),
    Context = #{generated_tests => Tests},
    convert_events(maybe_generate_test:handle(Cmd, Context), fun test_generated_v1:to_map/1).

execute_pause_generation(Payload, _State) ->
    {ok, Cmd} = pause_generation_v1:from_map(Payload),
    convert_events(maybe_pause_generation:handle(Cmd), fun generation_paused_v1:to_map/1).

execute_resume_generation(Payload, _State) ->
    {ok, Cmd} = resume_generation_v1:from_map(Payload),
    convert_events(maybe_resume_generation:handle(Cmd), fun generation_resumed_v1:to_map/1).

execute_complete_generation(Payload, _State) ->
    {ok, Cmd} = complete_generation_v1:from_map(Payload),
    convert_events(maybe_complete_generation:handle(Cmd), fun generation_completed_v1:to_map/1).

execute_archive_generation(Payload, _State) ->
    {ok, Cmd} = archive_generation_v1:from_map(Payload),
    convert_events(maybe_archive_generation:handle(Cmd), fun generation_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"generation_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"generation_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"module_generated_v1">>} = E) ->
    apply_module_generated(E, State);
apply(State, #{event_type := <<"module_generated_v1">>} = E) ->
    apply_module_generated(E, State);

apply(State, #{<<"event_type">> := <<"test_generated_v1">>} = E) ->
    apply_test_generated(E, State);
apply(State, #{event_type := <<"test_generated_v1">>} = E) ->
    apply_test_generated(E, State);

apply(State, #{<<"event_type">> := <<"generation_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"generation_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"generation_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"generation_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"generation_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"generation_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"generation_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"generation_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?GENERATION_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?GENERATION_ACTIVE),
    State#generation_state{
        division_id = get_value(division_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_module_generated(E, State) ->
    ModuleName = get_value(module_name, E),
    Details = #{
        module_name => ModuleName,
        module_path => get_value(module_path, E),
        module_type => get_value(module_type, E),
        generated_at => get_value(generated_at, E)
    },
    Modules = State#generation_state.generated_modules,
    State#generation_state{
        generated_modules = Modules#{ModuleName => Details}
    }.

apply_test_generated(E, State) ->
    TestName = get_value(test_name, E),
    Details = #{
        test_name => TestName,
        test_path => get_value(test_path, E),
        test_type => get_value(test_type, E),
        generated_at => get_value(generated_at, E)
    },
    Tests = State#generation_state.generated_tests,
    State#generation_state{
        generated_tests = Tests#{TestName => Details}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#generation_state.status, ?GENERATION_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?GENERATION_PAUSED),
    State#generation_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#generation_state.status, ?GENERATION_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?GENERATION_ACTIVE),
    State#generation_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#generation_state.status, ?GENERATION_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?GENERATION_COMPLETED),
    State#generation_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#generation_state{
        status = evoq_bit_flags:set(State#generation_state.status, ?GENERATION_ARCHIVED)
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
