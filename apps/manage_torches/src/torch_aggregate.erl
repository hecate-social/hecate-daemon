%%% @doc Torch aggregate
%%% Maintains Torch state and applies events.
%%% A Torch represents a high-level project or initiative containing multiple Cartwheels.
-module(torch_aggregate).
-behaviour(evoq_aggregate).

-include("torch_status.hrl").

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Aliases for backward compatibility and testing
-export([initial_state/0, apply_event/2]).

%% Bit flag descriptions for status display
-export([flag_map/0]).

%% Local aliases for readability (from torch_status.hrl)
-define(INITIATED,     ?TORCH_INITIATED).
-define(DNA_ACTIVE,    ?TORCH_DNA_ACTIVE).
-define(DNA_COMPLETE,  ?TORCH_DNA_COMPLETE).
-define(IMPLEMENTING,  ?TORCH_IMPLEMENTING).
-define(COMPLETED,     ?TORCH_COMPLETED).
-define(ARCHIVED,      ?TORCH_ARCHIVED).

-record(torch_state, {
    torch_id            :: binary() | undefined,
    name                :: binary() | undefined,
    brief               :: binary() | undefined,
    status              :: non_neg_integer(),
    repos               :: [binary()],
    skills              :: [binary()],
    context_map         :: map(),
    identified_cartwheels :: map(),  %% context_name => cartwheel_id
    active_cartwheel_id :: binary() | undefined,
    initiated_at        :: non_neg_integer() | undefined,
    initiated_by        :: binary() | undefined
}).

-type state() :: #torch_state{}.
-export_type([state/0]).

%% @doc Flag map for status display via evoq_bit_flags:to_string/2
-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?TORCH_FLAG_MAP.

%% @doc Behaviour callback: init/1
-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #torch_state{
        torch_id = undefined,
        name = undefined,
        brief = undefined,
        status = 0,
        repos = [],
        skills = [],
        context_map = #{},
        identified_cartwheels = #{},
        active_cartwheel_id = undefined,
        initiated_at = undefined,
        initiated_by = undefined
    }.

%% @doc Execute command against aggregate state
%% NOTE: evoq calls execute(State, Payload) - state first, then payload!
%% Supports both atom keys (from tests) and binary keys (from to_map/evoq dispatch).
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_torch">> -> execute_initiate_torch(Payload, State);
        <<"identify_cartwheel">> -> execute_identify_cartwheel(Payload, State);
        <<"activate_cartwheel">> -> execute_activate_cartwheel(Payload, State);
        <<"refine_vision">> -> execute_refine_vision(Payload, State);
        <<"submit_vision">> -> execute_submit_vision(Payload, State);
        <<"archive_torch">> -> execute_archive_torch(Payload, State);
        _ -> {error, unknown_command}
    end.

%% Extract command_type from atom or binary keyed map
get_command_type(#{command_type := V}) -> V;
get_command_type(#{<<"command_type">> := V}) -> V;
get_command_type(_) -> undefined.

execute_initiate_torch(Payload, #torch_state{status = 0}) ->
    {ok, Cmd} = initiate_torch_v1:from_map(Payload),
    convert_events(maybe_initiate_torch:handle(Cmd), fun torch_initiated_v1:to_map/1);
execute_initiate_torch(_Payload, _State) ->
    {error, torch_already_initiated}.

execute_identify_cartwheel(_Payload, #torch_state{torch_id = undefined}) ->
    {error, torch_not_found};
execute_identify_cartwheel(_Payload, #torch_state{status = Status}) when Status band ?INITIATED =:= 0 ->
    {error, torch_not_initiated};
execute_identify_cartwheel(Payload, #torch_state{identified_cartwheels = Identified} = _State) ->
    {ok, Cmd} = identify_cartwheel_v1:from_map(Payload),
    Context = #{identified_cartwheels => Identified},
    convert_events(maybe_identify_cartwheel:handle(Cmd, Context), fun cartwheel_identified_v1:to_map/1).

execute_activate_cartwheel(_Payload, #torch_state{torch_id = undefined}) ->
    {error, torch_not_found};
execute_activate_cartwheel(Payload, #torch_state{status = Status} = _State) when Status band ?INITIATED =/= 0 ->
    {ok, Cmd} = activate_cartwheel_v1:from_map(Payload),
    convert_events(maybe_activate_cartwheel:handle(Cmd), fun cartwheel_activated_v1:to_map/1);
execute_activate_cartwheel(_Payload, _State) ->
    {error, torch_not_initiated}.

execute_refine_vision(_Payload, #torch_state{torch_id = undefined}) ->
    {error, torch_not_found};
execute_refine_vision(_Payload, #torch_state{status = Status}) when Status band ?ARCHIVED =/= 0 ->
    {error, torch_archived};
execute_refine_vision(_Payload, #torch_state{status = Status}) when Status band ?DNA_ACTIVE =:= 0 ->
    {error, dna_not_active};
execute_refine_vision(Payload, _State) ->
    {ok, Cmd} = refine_vision_v1:from_map(Payload),
    convert_events(maybe_refine_vision:handle(Cmd), fun torch_vision_refined_v1:to_map/1).

execute_submit_vision(_Payload, #torch_state{torch_id = undefined}) ->
    {error, torch_not_found};
execute_submit_vision(_Payload, #torch_state{status = Status}) when Status band ?ARCHIVED =/= 0 ->
    {error, torch_archived};
execute_submit_vision(_Payload, #torch_state{status = Status}) when Status band ?DNA_ACTIVE =:= 0 ->
    {error, dna_not_active};
execute_submit_vision(_Payload, #torch_state{status = Status}) when Status band ?DNA_COMPLETE =/= 0 ->
    {error, dna_already_complete};
execute_submit_vision(Payload, _State) ->
    {ok, Cmd} = submit_vision_v1:from_map(Payload),
    convert_events(maybe_submit_vision:handle(Cmd), fun torch_vision_submitted_v1:to_map/1).

execute_archive_torch(_Payload, #torch_state{torch_id = undefined}) ->
    {error, torch_not_found};
execute_archive_torch(_Payload, #torch_state{status = Status}) when Status band ?ARCHIVED =/= 0 ->
    {error, torch_already_archived};
execute_archive_torch(_Payload, #torch_state{status = Status}) when Status band ?INITIATED =:= 0 ->
    {error, torch_not_initiated};
execute_archive_torch(Payload, _State) ->
    {ok, Cmd} = archive_torch_v1:from_map(Payload),
    convert_events(maybe_archive_torch:handle(Cmd), fun torch_archived_v1:to_map/1).

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

%% @doc Behaviour callback: apply/2
%% NOTE: evoq calls apply(State, Event) - state first, then event!
-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

%% @doc Apply event to state (event sourcing)
%% Legacy function with (Event, State) order - use apply/2 instead
-spec apply_event(map(), state()) -> state().
apply_event(#{<<"event_type">> := <<"torch_initiated_v1">>} = E, State) ->
    apply_torch_initiated(E, State);
apply_event(#{event_type := <<"torch_initiated_v1">>} = E, State) ->
    apply_torch_initiated(E, State);
apply_event(#{<<"event_type">> := <<"cartwheel_identified_v1">>} = E, State) ->
    apply_cartwheel_identified(E, State);
apply_event(#{event_type := <<"cartwheel_identified_v1">>} = E, State) ->
    apply_cartwheel_identified(E, State);
apply_event(#{<<"event_type">> := <<"cartwheel_activated_v1">>} = E, State) ->
    apply_cartwheel_activated(E, State);
apply_event(#{event_type := <<"cartwheel_activated_v1">>} = E, State) ->
    apply_cartwheel_activated(E, State);
apply_event(#{<<"event_type">> := <<"torch_vision_refined_v1">>} = E, State) ->
    apply_torch_vision_refined(E, State);
apply_event(#{event_type := <<"torch_vision_refined_v1">>} = E, State) ->
    apply_torch_vision_refined(E, State);
apply_event(#{<<"event_type">> := <<"torch_vision_submitted_v1">>} = _E, State) ->
    apply_torch_vision_submitted(State);
apply_event(#{event_type := <<"torch_vision_submitted_v1">>} = _E, State) ->
    apply_torch_vision_submitted(State);
apply_event(#{<<"event_type">> := <<"torch_archived_v1">>} = _E, State) ->
    apply_torch_archived(State);
apply_event(#{event_type := <<"torch_archived_v1">>} = _E, State) ->
    apply_torch_archived(State);
apply_event(_E, State) ->
    State.

apply_torch_initiated(E, State) ->
    State#torch_state{
        torch_id = get_value(torch_id, E),
        name = get_value(name, E),
        brief = get_value(brief, E),
        status = evoq_bit_flags:set_all(0, [?INITIATED, ?DNA_ACTIVE]),
        repos = get_value(repos, E, []),
        skills = get_value(skills, E, []),
        context_map = get_value(context_map, E, #{}),
        initiated_at = get_value(initiated_at, E),
        initiated_by = get_value(initiated_by, E)
    }.

apply_cartwheel_identified(E, State) ->
    CartwheelId = get_value(cartwheel_id, E),
    ContextName = get_value(context_name, E),
    CurrentIdentified = State#torch_state.identified_cartwheels,
    UpdatedIdentified = CurrentIdentified#{ContextName => CartwheelId},
    State#torch_state{
        identified_cartwheels = UpdatedIdentified
    }.

apply_cartwheel_activated(E, State) ->
    CartwheelId = get_value(cartwheel_id, E),
    ContextName = get_value(context_name, E),
    CurrentMap = State#torch_state.context_map,
    UpdatedMap = CurrentMap#{ContextName => CartwheelId},
    State#torch_state{
        active_cartwheel_id = CartwheelId,
        context_map = UpdatedMap
    }.

apply_torch_vision_refined(E, State) ->
    %% Only update fields that are non-undefined (partial update)
    S1 = case get_value(brief, E) of
        undefined -> State;
        Brief -> State#torch_state{brief = Brief}
    end,
    S2 = case get_value(repos, E) of
        undefined -> S1;
        Repos -> S1#torch_state{repos = Repos}
    end,
    S3 = case get_value(skills, E) of
        undefined -> S2;
        Skills -> S2#torch_state{skills = Skills}
    end,
    case get_value(context_map, E) of
        undefined -> S3;
        ContextMap -> S3#torch_state{context_map = ContextMap}
    end.

apply_torch_vision_submitted(#torch_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(evoq_bit_flags:set(Status, ?DNA_COMPLETE), ?DNA_ACTIVE),
    State#torch_state{status = NewStatus}.

apply_torch_archived(#torch_state{status = Status} = State) ->
    State#torch_state{
        status = evoq_bit_flags:set(Status, ?ARCHIVED)
    }.

%% Helper to get value from map with atom or binary keys
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
