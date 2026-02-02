%%% @doc Identity aggregate
%%% Maintains identity registration state.
-module(identity_aggregate).

-export([initial_state/0, execute/2, apply_event/2]).

-record(identity_state, {
    mri :: binary() | undefined,
    public_key :: binary() | undefined,
    key_type :: binary() | undefined,
    metadata :: map(),
    registered :: boolean(),
    registered_at :: integer() | undefined
}).

-opaque identity_state() :: #identity_state{}.
-export_type([identity_state/0]).

%% @doc Initial empty state for evoq.
-spec initial_state() -> identity_state().
initial_state() ->
    #identity_state{
        mri = undefined,
        public_key = undefined,
        key_type = undefined,
        metadata = #{},
        registered = false,
        registered_at = undefined
    }.

%% @doc Execute command against aggregate state (evoq callback).
-spec execute(map(), identity_state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := register_identity} = Payload, State) ->
    case State#identity_state.registered of
        true ->
            {error, identity_already_registered};
        false ->
            {ok, Cmd} = register_identity_v1:from_map(Payload),
            execute_handler(maybe_register_identity:handle(Cmd))
    end;
execute(#{command_type := update_identity} = Payload, State) ->
    case State#identity_state.registered of
        true ->
            {ok, Cmd} = update_identity_v1:from_map(Payload),
            execute_handler(maybe_update_identity:handle(Cmd));
        false ->
            {error, identity_not_registered}
    end;
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
-spec apply_event(map(), identity_state()) -> identity_state().
apply_event(#{
    event_type := <<"identity_registered_v1">>,
    mri := MRI,
    public_key := PublicKey,
    key_type := KeyType,
    metadata := Metadata,
    registered_at := RegisteredAt
}, Agg) ->
    Agg#identity_state{
        mri = MRI,
        public_key = PublicKey,
        key_type = KeyType,
        metadata = Metadata,
        registered = true,
        registered_at = RegisteredAt
    };

apply_event(#{
    event_type := <<"identity_updated_v1">>,
    metadata := Metadata
}, Agg) ->
    %% Merge new metadata with existing
    NewMetadata = maps:merge(Agg#identity_state.metadata, Metadata),
    Agg#identity_state{metadata = NewMetadata};

apply_event(_OtherEvent, Agg) ->
    Agg.
