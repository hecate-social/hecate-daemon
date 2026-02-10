%%% @doc Aggregate for the testing process.
%%%
%%% Lifecycle: pending -> active -> paused -> completed
%%% Domain commands: run_test_suite (only when active),
%%%                  record_test_result (only when active)
%%% Stream: testing-{division_id}
%%% @end
-module(testing_aggregate).

-behaviour(evoq_aggregate).

-include_lib("test_division/include/testing_status.hrl").

-export([init/1, execute/2, apply/2]).

-record(testing_state, {
    division_id = undefined :: binary() | undefined,
    status = 0 :: non_neg_integer(),
    test_suites = #{} :: #{binary() => map()},
    test_results = #{} :: #{binary() => map()},
    started_at = undefined :: non_neg_integer() | undefined,
    paused_at = undefined :: non_neg_integer() | undefined,
    completed_at = undefined :: non_neg_integer() | undefined,
    pause_reason = undefined :: binary() | undefined
}).

%% --- Callbacks ---

init(_Args) ->
    {ok, #testing_state{}}.

%% --- Execute: lifecycle commands ---

%% Start testing (only on fresh aggregate)
execute(#testing_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"start_testing">> -> execute_start_testing(Payload);
        _ -> {error, testing_not_started}
    end;

%% Archive (only if initiated and not already archived)
execute(#testing_state{status = S} = State, Payload)
  when S band ?TESTING_ARCHIVED =:= 0, S band ?TESTING_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_testing">> -> execute_archive_testing(Payload, State);
        Other -> execute_lifecycle(Other, Payload, State)
    end;

%% Already archived
execute(#testing_state{status = S}, _Payload)
  when S band ?TESTING_ARCHIVED =/= 0 ->
    {error, testing_archived};

%% Catch-all
execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Execute: lifecycle + domain commands ---

execute_lifecycle(<<"run_test_suite">>, Payload, #testing_state{status = S} = State)
  when S band ?TESTING_ACTIVE =/= 0 ->
    execute_run_test_suite(Payload, State);
execute_lifecycle(<<"run_test_suite">>, _Payload, #testing_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"record_test_result">>, Payload, #testing_state{status = S} = State)
  when S band ?TESTING_ACTIVE =/= 0 ->
    execute_record_test_result(Payload, State);
execute_lifecycle(<<"record_test_result">>, _Payload, #testing_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"pause_testing">>, Payload, #testing_state{status = S} = State)
  when S band ?TESTING_ACTIVE =/= 0 ->
    execute_pause_testing(Payload, State);
execute_lifecycle(<<"pause_testing">>, _Payload, #testing_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(<<"resume_testing">>, Payload, #testing_state{status = S} = State)
  when S band ?TESTING_PAUSED =/= 0 ->
    execute_resume_testing(Payload, State);
execute_lifecycle(<<"resume_testing">>, _Payload, #testing_state{status = S}) ->
    {error, {not_paused, S}};

execute_lifecycle(<<"complete_testing">>, Payload, #testing_state{status = S} = State)
  when S band ?TESTING_ACTIVE =/= 0 ->
    execute_complete_testing(Payload, State);
execute_lifecycle(<<"complete_testing">>, _Payload, #testing_state{status = S}) ->
    {error, {not_active, S}};

execute_lifecycle(_, _Payload, _State) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_start_testing(Payload) ->
    {ok, Cmd} = start_testing_v1:from_map(Payload),
    convert_events(maybe_start_testing:handle(Cmd), fun testing_started_v1:to_map/1).

execute_run_test_suite(Payload, #testing_state{test_suites = Suites}) ->
    {ok, Cmd} = run_test_suite_v1:from_map(Payload),
    Context = #{test_suites => Suites},
    convert_events(maybe_run_test_suite:handle(Cmd, Context), fun test_suite_run_v1:to_map/1).

execute_record_test_result(Payload, #testing_state{test_results = Results}) ->
    {ok, Cmd} = record_test_result_v1:from_map(Payload),
    Context = #{test_results => Results},
    convert_events(maybe_record_test_result:handle(Cmd, Context), fun test_result_recorded_v1:to_map/1).

execute_pause_testing(Payload, _State) ->
    {ok, Cmd} = pause_testing_v1:from_map(Payload),
    convert_events(maybe_pause_testing:handle(Cmd), fun testing_paused_v1:to_map/1).

execute_resume_testing(Payload, _State) ->
    {ok, Cmd} = resume_testing_v1:from_map(Payload),
    convert_events(maybe_resume_testing:handle(Cmd), fun testing_resumed_v1:to_map/1).

execute_complete_testing(Payload, _State) ->
    {ok, Cmd} = complete_testing_v1:from_map(Payload),
    convert_events(maybe_complete_testing:handle(Cmd), fun testing_completed_v1:to_map/1).

execute_archive_testing(Payload, _State) ->
    {ok, Cmd} = archive_testing_v1:from_map(Payload),
    convert_events(maybe_archive_testing:handle(Cmd), fun testing_archived_v1:to_map/1).

%% --- Apply ---

apply(State, #{<<"event_type">> := <<"testing_started_v1">>} = E) ->
    apply_started(E, State);
apply(State, #{event_type := <<"testing_started_v1">>} = E) ->
    apply_started(E, State);

apply(State, #{<<"event_type">> := <<"test_suite_run_v1">>} = E) ->
    apply_test_suite_run(E, State);
apply(State, #{event_type := <<"test_suite_run_v1">>} = E) ->
    apply_test_suite_run(E, State);

apply(State, #{<<"event_type">> := <<"test_result_recorded_v1">>} = E) ->
    apply_test_result_recorded(E, State);
apply(State, #{event_type := <<"test_result_recorded_v1">>} = E) ->
    apply_test_result_recorded(E, State);

apply(State, #{<<"event_type">> := <<"testing_paused_v1">>} = E) ->
    apply_paused(E, State);
apply(State, #{event_type := <<"testing_paused_v1">>} = E) ->
    apply_paused(E, State);

apply(State, #{<<"event_type">> := <<"testing_resumed_v1">>} = E) ->
    apply_resumed(E, State);
apply(State, #{event_type := <<"testing_resumed_v1">>} = E) ->
    apply_resumed(E, State);

apply(State, #{<<"event_type">> := <<"testing_completed_v1">>} = E) ->
    apply_completed(E, State);
apply(State, #{event_type := <<"testing_completed_v1">>} = E) ->
    apply_completed(E, State);

apply(State, #{<<"event_type">> := <<"testing_archived_v1">>} = E) ->
    apply_archived(E, State);
apply(State, #{event_type := <<"testing_archived_v1">>} = E) ->
    apply_archived(E, State);

apply(State, _Unknown) ->
    State.

%% --- Apply helpers ---

apply_started(E, State) ->
    S0 = evoq_bit_flags:set(0, ?TESTING_INITIATED),
    S1 = evoq_bit_flags:set(S0, ?TESTING_ACTIVE),
    State#testing_state{
        division_id = get_value(division_id, E),
        status = S1,
        started_at = get_value(started_at, E)
    }.

apply_test_suite_run(E, State) ->
    SuiteId = get_value(suite_id, E),
    Details = #{
        suite_id => SuiteId,
        suite_name => get_value(suite_name, E),
        suite_type => get_value(suite_type, E),
        target_module => get_value(target_module, E),
        run_at => get_value(run_at, E)
    },
    Suites = State#testing_state.test_suites,
    State#testing_state{
        test_suites = Suites#{SuiteId => Details}
    }.

apply_test_result_recorded(E, State) ->
    ResultId = get_value(result_id, E),
    Details = #{
        result_id => ResultId,
        suite_id => get_value(suite_id, E),
        test_name => get_value(test_name, E),
        status => get_value(status, E),
        details => get_value(details, E),
        recorded_at => get_value(recorded_at, E)
    },
    Results = State#testing_state.test_results,
    State#testing_state{
        test_results = Results#{ResultId => Details}
    }.

apply_paused(E, State) ->
    S0 = evoq_bit_flags:unset(State#testing_state.status, ?TESTING_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?TESTING_PAUSED),
    State#testing_state{
        status = S1,
        paused_at = get_value(paused_at, E),
        pause_reason = get_value(reason, E)
    }.

apply_resumed(_E, State) ->
    S0 = evoq_bit_flags:unset(State#testing_state.status, ?TESTING_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?TESTING_ACTIVE),
    State#testing_state{
        status = S1,
        paused_at = undefined,
        pause_reason = undefined
    }.

apply_completed(E, State) ->
    S0 = evoq_bit_flags:unset(State#testing_state.status, ?TESTING_ACTIVE),
    S1 = evoq_bit_flags:set(S0, ?TESTING_COMPLETED),
    State#testing_state{
        status = S1,
        completed_at = get_value(completed_at, E)
    }.

apply_archived(_E, State) ->
    State#testing_state{
        status = evoq_bit_flags:set(State#testing_state.status, ?TESTING_ARCHIVED)
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
