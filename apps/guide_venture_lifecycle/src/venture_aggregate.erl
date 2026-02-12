%%% @doc Venture aggregate — unified lifecycle for inception + discovery.
%%%
%%% Absorbs: setup_aggregate (setup_venture) + discovery_aggregate (discover_divisions)
%%% Stream: venture-{venture_id}
%%% Store: dev_studio_store
%%%
%%% Lifecycle:
%%%   1. initiate_venture (birth event)
%%%   2. refine_vision / submit_vision (inception phase)
%%%   3. start_discovery / identify_division / pause/resume/complete_discovery
%%%   4. archive_venture (walking skeleton)
%%% @end
-module(venture_aggregate).

-behaviour(evoq_aggregate).

-include("venture_lifecycle_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-record(venture_state, {
    venture_id          :: binary() | undefined,
    name                :: binary() | undefined,
    brief               :: binary() | undefined,
    status = 0          :: non_neg_integer(),
    repos = []          :: [binary()],
    skills = []         :: [binary()],
    context_map = #{}   :: map(),
    discovered_divisions = #{} :: #{binary() => binary()},
    initiated_at        :: non_neg_integer() | undefined,
    initiated_by        :: binary() | undefined,
    discovery_started_at   :: non_neg_integer() | undefined,
    discovery_paused_at    :: non_neg_integer() | undefined,
    discovery_completed_at :: non_neg_integer() | undefined,
    discovery_pause_reason :: binary() | undefined
}).

-type state() :: #venture_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?VL_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #venture_state{}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate allowed
execute(#venture_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_venture">> -> execute_initiate_venture(Payload);
        _ -> {error, venture_not_initiated}
    end;

%% Archived — nothing allowed
execute(#venture_state{status = S}, _Payload) when S band ?VL_ARCHIVED =/= 0 ->
    {error, venture_archived};

%% Initiated and not archived — route by command type
execute(#venture_state{status = S} = State, Payload) when S band ?VL_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"refine_vision">>      -> execute_refine_vision(Payload, State);
        <<"submit_vision">>      -> execute_submit_vision(Payload, State);
        <<"start_discovery">>    -> execute_start_discovery(Payload, State);
        <<"identify_division">>  -> execute_identify_division(Payload, State);
        <<"pause_discovery">>    -> execute_pause_discovery(Payload, State);
        <<"resume_discovery">>   -> execute_resume_discovery(Payload, State);
        <<"complete_discovery">> -> execute_complete_discovery(Payload, State);
        <<"archive_venture">>    -> execute_archive_venture(Payload, State);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_venture(Payload) ->
    {ok, Cmd} = initiate_venture_v1:from_map(Payload),
    convert_events(maybe_initiate_venture:handle(Cmd), fun venture_initiated_v1:to_map/1).

execute_refine_vision(Payload, #venture_state{status = S}) ->
    case S band ?VL_SUBMITTED of
        0 ->
            {ok, Cmd} = refine_vision_v1:from_map(Payload),
            convert_events(maybe_refine_vision:handle(Cmd), fun vision_refined_v1:to_map/1);
        _ ->
            {error, vision_already_submitted}
    end.

execute_submit_vision(Payload, #venture_state{status = S}) ->
    case S band ?VL_SUBMITTED of
        0 ->
            {ok, Cmd} = submit_vision_v1:from_map(Payload),
            convert_events(maybe_submit_vision:handle(Cmd), fun vision_submitted_v1:to_map/1);
        _ ->
            {error, vision_already_submitted}
    end.

execute_start_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERING of
        0 ->
            case S band ?VL_DISCOVERY_COMPLETED of
                0 ->
                    {ok, Cmd} = start_discovery_v1:from_map(Payload),
                    convert_events(maybe_start_discovery:handle(Cmd), fun discovery_started_v1:to_map/1);
                _ ->
                    {error, discovery_already_completed}
            end;
        _ ->
            {error, discovery_already_started}
    end.

execute_identify_division(Payload, #venture_state{status = S, discovered_divisions = Discovered}) ->
    case S band ?VL_DISCOVERING of
        0 -> {error, discovery_not_active};
        _ ->
            {ok, Cmd} = identify_division_v1:from_map(Payload),
            Context = #{discovered_divisions => Discovered},
            convert_events(maybe_identify_division:handle(Cmd, Context), fun division_identified_v1:to_map/1)
    end.

execute_pause_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERING of
        0 -> {error, discovery_not_active};
        _ ->
            {ok, Cmd} = pause_discovery_v1:from_map(Payload),
            convert_events(maybe_pause_discovery:handle(Cmd), fun discovery_paused_v1:to_map/1)
    end.

execute_resume_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERY_PAUSED of
        0 -> {error, discovery_not_paused};
        _ ->
            {ok, Cmd} = resume_discovery_v1:from_map(Payload),
            convert_events(maybe_resume_discovery:handle(Cmd), fun discovery_resumed_v1:to_map/1)
    end.

execute_complete_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERING of
        0 -> {error, discovery_not_active};
        _ ->
            {ok, Cmd} = complete_discovery_v1:from_map(Payload),
            convert_events(maybe_complete_discovery:handle(Cmd), fun discovery_completed_v1:to_map/1)
    end.

execute_archive_venture(Payload, _State) ->
    {ok, Cmd} = archive_venture_v1:from_map(Payload),
    convert_events(maybe_archive_venture:handle(Cmd), fun venture_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

%% Inception events
apply_event(#{<<"event_type">> := <<"venture_initiated_v1">>} = E, S) -> apply_initiated(E, S);
apply_event(#{event_type := <<"venture_initiated_v1">>} = E, S)      -> apply_initiated(E, S);
apply_event(#{<<"event_type">> := <<"vision_refined_v1">>} = E, S)   -> apply_vision_refined(E, S);
apply_event(#{event_type := <<"vision_refined_v1">>} = E, S)         -> apply_vision_refined(E, S);
apply_event(#{<<"event_type">> := <<"vision_submitted_v1">>} = E, S) -> apply_vision_submitted(E, S);
apply_event(#{event_type := <<"vision_submitted_v1">>} = E, S)       -> apply_vision_submitted(E, S);

%% Discovery events
apply_event(#{<<"event_type">> := <<"discovery_started_v1">>} = E, S)   -> apply_discovery_started(E, S);
apply_event(#{event_type := <<"discovery_started_v1">>} = E, S)         -> apply_discovery_started(E, S);
apply_event(#{<<"event_type">> := <<"division_identified_v1">>} = E, S) -> apply_division_identified(E, S);
apply_event(#{event_type := <<"division_identified_v1">>} = E, S)       -> apply_division_identified(E, S);
apply_event(#{<<"event_type">> := <<"discovery_paused_v1">>} = E, S)    -> apply_discovery_paused(E, S);
apply_event(#{event_type := <<"discovery_paused_v1">>} = E, S)          -> apply_discovery_paused(E, S);
apply_event(#{<<"event_type">> := <<"discovery_resumed_v1">>} = _E, S)  -> apply_discovery_resumed(S);
apply_event(#{event_type := <<"discovery_resumed_v1">>} = _E, S)        -> apply_discovery_resumed(S);
apply_event(#{<<"event_type">> := <<"discovery_completed_v1">>} = E, S) -> apply_discovery_completed(E, S);
apply_event(#{event_type := <<"discovery_completed_v1">>} = E, S)       -> apply_discovery_completed(E, S);

%% Archive
apply_event(#{<<"event_type">> := <<"venture_archived_v1">>} = _E, S) -> apply_archived(S);
apply_event(#{event_type := <<"venture_archived_v1">>} = _E, S)       -> apply_archived(S);

%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_initiated(E, State) ->
    State#venture_state{
        venture_id = get_value(venture_id, E),
        name = get_value(name, E),
        brief = get_value(brief, E),
        status = evoq_bit_flags:set(0, ?VL_INITIATED),
        repos = get_value(repos, E, []),
        skills = get_value(skills, E, []),
        context_map = get_value(context_map, E, #{}),
        initiated_at = get_value(initiated_at, E),
        initiated_by = get_value(initiated_by, E)
    }.

apply_vision_refined(E, #venture_state{status = Status} = State) ->
    S1 = maybe_update(brief, E, State),
    S2 = maybe_update(repos, E, S1),
    S3 = maybe_update(skills, E, S2),
    S4 = maybe_update(context_map, E, S3),
    S4#venture_state{status = evoq_bit_flags:set(Status, ?VL_VISION_REFINED)}.

apply_vision_submitted(_E, #venture_state{status = Status} = State) ->
    State#venture_state{status = evoq_bit_flags:set(Status, ?VL_SUBMITTED)}.

apply_discovery_started(E, #venture_state{status = Status} = State) ->
    State#venture_state{
        status = evoq_bit_flags:set(Status, ?VL_DISCOVERING),
        discovery_started_at = get_value(started_at, E)
    }.

apply_division_identified(E, State) ->
    DivisionId = get_value(division_id, E),
    ContextName = get_value(context_name, E),
    Discovered = State#venture_state.discovered_divisions,
    State#venture_state{
        discovered_divisions = Discovered#{ContextName => DivisionId}
    }.

apply_discovery_paused(E, #venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_DISCOVERING),
    S1 = evoq_bit_flags:set(S0, ?VL_DISCOVERY_PAUSED),
    State#venture_state{
        status = S1,
        discovery_paused_at = get_value(paused_at, E),
        discovery_pause_reason = get_value(reason, E)
    }.

apply_discovery_resumed(#venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_DISCOVERY_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?VL_DISCOVERING),
    State#venture_state{
        status = S1,
        discovery_paused_at = undefined,
        discovery_pause_reason = undefined
    }.

apply_discovery_completed(E, #venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_DISCOVERING),
    S1 = evoq_bit_flags:set(S0, ?VL_DISCOVERY_COMPLETED),
    State#venture_state{
        status = S1,
        discovery_completed_at = get_value(completed_at, E)
    }.

apply_archived(#venture_state{status = Status} = State) ->
    State#venture_state{status = evoq_bit_flags:set(Status, ?VL_ARCHIVED)}.

%% --- Internal ---

maybe_update(Field, E, State) ->
    case get_value(Field, E) of
        undefined -> State;
        Value -> set_field(Field, Value, State)
    end.

set_field(brief, V, S) -> S#venture_state{brief = V};
set_field(repos, V, S) -> S#venture_state{repos = V};
set_field(skills, V, S) -> S#venture_state{skills = V};
set_field(context_map, V, S) -> S#venture_state{context_map = V}.

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
