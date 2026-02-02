-module(reputation_aggregate).

-export([initial_state/0, execute/2, apply_event/2]).

-record(reputation_aggregate, {
    agent_identity :: binary() | undefined,
    total_calls :: non_neg_integer(),
    successful_calls :: non_neg_integer(),
    failed_calls :: non_neg_integer(),
    total_duration_ms :: non_neg_integer(),
    disputes_flagged :: non_neg_integer(),
    disputes_upheld :: non_neg_integer(),
    reputation_score :: float()
}).

-opaque reputation_aggregate() :: #reputation_aggregate{}.
-export_type([reputation_aggregate/0]).

%% @doc Initial empty state for evoq.
-spec initial_state() -> reputation_aggregate().
initial_state() ->
    #reputation_aggregate{
        agent_identity = undefined,
        total_calls = 0,
        successful_calls = 0,
        failed_calls = 0,
        total_duration_ms = 0,
        disputes_flagged = 0,
        disputes_upheld = 0,
        reputation_score = 0.0
    }.

%% @doc Execute command against aggregate state (evoq callback).
-spec execute(map(), reputation_aggregate()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := track_rpc_call} = Payload, _State) ->
    {ok, Cmd} = track_rpc_call_v1:from_map(Payload),
    execute_handler(maybe_track_rpc_call:handle(Cmd));
execute(#{command_type := flag_dispute} = Payload, _State) ->
    {ok, Cmd} = flag_dispute_v1:from_map(Payload),
    execute_handler(maybe_flag_dispute:handle(Cmd));
execute(#{command_type := resolve_dispute} = Payload, _State) ->
    {ok, Cmd} = resolve_dispute_v1:from_map(Payload),
    execute_handler(maybe_resolve_dispute:handle(Cmd));
execute(_UnknownCommand, _State) ->
    {error, unknown_command}.

execute_handler({ok, Events}) ->
    EventMaps = [event_to_map(E) || E <- Events],
    {ok, EventMaps};
execute_handler({error, Reason}) ->
    {error, Reason}.

%% Events are always maps in this system
event_to_map(Event) when is_map(Event) -> Event.

%% @doc Apply event to aggregate state (snake_case_vN binary event types).
-spec apply_event(map(), reputation_aggregate()) -> reputation_aggregate().
apply_event(#{event_type := <<"rpc_call_tracked_v1">>, callee_identity := Callee} = Event, Agg) ->
    Duration = maps:get(call_duration_ms, Event),
    Success = maps:get(success, Event),

    %% Update aggregate state if this call involves this agent
    case Callee =:= Agg#reputation_aggregate.agent_identity of
        true ->
            SuccessIncr = case Success of true -> 1; false -> 0 end,
            FailIncr = case Success of false -> 1; true -> 0 end,
            NewAgg = Agg#reputation_aggregate{
                total_calls = Agg#reputation_aggregate.total_calls + 1,
                successful_calls = Agg#reputation_aggregate.successful_calls + SuccessIncr,
                failed_calls = Agg#reputation_aggregate.failed_calls + FailIncr,
                total_duration_ms = Agg#reputation_aggregate.total_duration_ms + Duration
            },
            NewAgg#reputation_aggregate{reputation_score = calculate_score(NewAgg)};
        false ->
            Agg
    end;

apply_event(#{event_type := <<"dispute_flagged_v1">>}, Agg) ->
    NewAgg = Agg#reputation_aggregate{
        disputes_flagged = Agg#reputation_aggregate.disputes_flagged + 1
    },
    NewAgg#reputation_aggregate{reputation_score = calculate_score(NewAgg)};

apply_event(#{event_type := <<"dispute_resolved_v1">>, resolution := upheld}, Agg) ->
    NewAgg = Agg#reputation_aggregate{
        disputes_upheld = Agg#reputation_aggregate.disputes_upheld + 1
    },
    NewAgg#reputation_aggregate{reputation_score = calculate_score(NewAgg)};

apply_event(_OtherEvent, Agg) ->
    Agg.

%% Internal functions

-spec calculate_score(reputation_aggregate()) -> float().
calculate_score(#reputation_aggregate{
    total_calls = Total,
    successful_calls = Success,
    disputes_upheld = Upheld
}) when Total > 0 ->
    %% Simple reputation scoring:
    %% - Base score: success rate (0.0 - 1.0)
    %% - Penalty: -0.1 per upheld dispute
    SuccessRate = Success / Total,
    DisputePenalty = Upheld * 0.1,
    max(0.0, SuccessRate - DisputePenalty);
calculate_score(_) ->
    0.0.
