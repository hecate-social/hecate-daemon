%%% @doc Capability aggregate
%%% Maintains capability state and applies events.
-module(capability_aggregate).

-export([execute/2, apply_event/2, initial_state/0]).

-record(capability_state, {
    mri :: binary() | undefined,
    agent_id :: binary() | undefined,
    tags :: [binary()],
    description :: binary() | undefined,
    demo_procedure :: binary() | undefined,
    metadata :: map(),
    announced_at :: non_neg_integer() | undefined,
    updated_at :: non_neg_integer() | undefined,
    retracted_at :: non_neg_integer() | undefined
}).

-type state() :: #capability_state{}.
-export_type([state/0]).

%% @doc Initialize empty state
-spec initial_state() -> state().
initial_state() ->
    #capability_state{
        mri = undefined,
        agent_id = undefined,
        tags = [],
        description = undefined,
        demo_procedure = undefined,
        metadata = #{},
        announced_at = undefined,
        updated_at = undefined,
        retracted_at = undefined
    }.

%% @doc Execute command against aggregate state
%% Dispatches to appropriate handler based on command_type
%% NOTE: evoq passes the command payload map, not the full #evoq_command{} record
-spec execute(map(), state()) ->
    {ok, [map()]} | {error, term()}.
execute(#{command_type := <<"update_capability">>} = Payload, State) ->
    execute_update(Payload, State);
execute(#{command_type := <<"retract_capability">>} = Payload, State) ->
    execute_retract(Payload, State);
execute(Payload, State) ->
    %% Default: announce_capability (no command_type or announce_capability)
    execute_announce(Payload, State).

execute_announce(Payload, _State) ->
    {ok, Cmd} = announce_capability_v1:from_map(Payload),
    convert_events(maybe_announce_capability:handle(Cmd), fun capability_announced_v1:to_map/1).

execute_update(Payload, State) ->
    case State#capability_state.mri of
        undefined ->
            {error, capability_not_found};
        _ ->
            {ok, Cmd} = update_capability_v1:from_map(Payload),
            convert_events(maybe_update_capability:handle(Cmd), fun capability_updated_v1:to_map/1)
    end.

execute_retract(Payload, State) ->
    case State#capability_state.mri of
        undefined ->
            {error, capability_not_found};
        _ ->
            case State#capability_state.retracted_at of
                undefined ->
                    {ok, Cmd} = retract_capability_v1:from_map(Payload),
                    convert_events(maybe_retract_capability:handle(Cmd), fun capability_retracted_v1:to_map/1);
                _ ->
                    {error, capability_already_retracted}
            end
    end.

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps}.

%% @doc Apply event to state (event sourcing)
%% NOTE: evoq passes event as map
-spec apply_event(map(), state()) -> state().
apply_event(#{event_type := <<"capability_announced_v1">>} = EventMap, State) ->
    State#capability_state{
        mri = maps:get(capability_mri, EventMap),
        agent_id = maps:get(agent_identity, EventMap),
        tags = maps:get(tags, EventMap),
        description = maps:get(description, EventMap),
        demo_procedure = maps:get(demo_procedure, EventMap, undefined),
        metadata = maps:get(metadata, EventMap, #{}),
        announced_at = maps:get(announced_at, EventMap, erlang:system_time(millisecond))
    };
apply_event(#{event_type := <<"capability_updated_v1">>} = EventMap, State) ->
    State#capability_state{
        tags = maps:get(tags, EventMap, State#capability_state.tags),
        description = maps:get(description, EventMap, State#capability_state.description),
        demo_procedure = maps:get(demo_procedure, EventMap, State#capability_state.demo_procedure),
        metadata = maps:get(metadata, EventMap, State#capability_state.metadata),
        updated_at = maps:get(updated_at, EventMap, erlang:system_time(millisecond))
    };
apply_event(#{event_type := <<"capability_retracted_v1">>} = EventMap, State) ->
    State#capability_state{
        retracted_at = maps:get(retracted_at, EventMap, erlang:system_time(millisecond))
    };
%% Fallback for events without event_type (backward compatibility)
apply_event(EventMap, State) ->
    State#capability_state{
        mri = maps:get(capability_mri, EventMap),
        agent_id = maps:get(agent_identity, EventMap),
        tags = maps:get(tags, EventMap),
        description = maps:get(description, EventMap),
        demo_procedure = maps:get(demo_procedure, EventMap, undefined),
        metadata = maps:get(metadata, EventMap, #{}),
        announced_at = maps:get(announced_at, EventMap, erlang:system_time(millisecond))
    }.
