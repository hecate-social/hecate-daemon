%%% @doc Connector aggregate
%%% Maintains connector state and applies events.
%%% Status is a bit flag integer: REGISTERED=1, ACTIVE=2, SUSPENDED=4, REVOKED=8
-module(connector_aggregate).
-behaviour(evoq_aggregate).

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% Aliases for backward compatibility and testing
-export([initial_state/0, apply_event/2]).

%% Bit flag descriptions for status display
-export([flag_map/0]).

%% Bit flags for connector status
-define(REGISTERED, 1).
-define(ACTIVE,     2).
-define(SUSPENDED,  4).
-define(REVOKED,    8).

-record(connector_state, {
    connector_id   :: binary() | undefined,
    name           :: binary() | undefined,
    socket_path    :: binary() | undefined,
    allowed_routes :: [binary()] | all,
    status         :: non_neg_integer(),
    metadata       :: map()
}).

-type state() :: #connector_state{}.
-export_type([state/0]).

%% @doc Flag map for status display via evoq_bit_flags:to_string/2
-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> #{
    0           => <<"New">>,
    ?REGISTERED => <<"📋 Registered">>,
    ?ACTIVE     => <<"🟢 Active">>,
    ?SUSPENDED  => <<"⏸️ Suspended">>,
    ?REVOKED    => <<"🚫 Revoked">>
}.

%% @doc Behaviour callback: init/1
-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

%% @doc Initialize empty state
-spec initial_state() -> state().
initial_state() ->
    #connector_state{
        connector_id = undefined,
        name = undefined,
        socket_path = undefined,
        allowed_routes = all,
        status = 0,
        metadata = #{}
    }.

%% @doc Execute command against aggregate state
%% NOTE: evoq calls execute(State, Payload) - state first, then payload!
-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, #{command_type := <<"revoke_connector">>} = Payload) ->
    execute_revoke(Payload, State);
execute(State, #{command_type := <<"activate_connector">>} = Payload) ->
    execute_activate(Payload, State);
execute(State, #{command_type := <<"suspend_connector">>} = Payload) ->
    execute_suspend(Payload, State);
execute(State, Payload) ->
    %% Default: register_connector
    execute_register(Payload, State).

execute_register(Payload, #connector_state{status = Status}) ->
    case evoq_bit_flags:has(Status, ?REGISTERED) of
        false ->
            {ok, Cmd} = register_connector_v1:from_map(Payload),
            convert_events(
                maybe_register_connector:handle(Cmd),
                fun connector_registered_v1:to_map/1);
        true ->
            {error, connector_already_registered}
    end.

execute_revoke(Payload, #connector_state{status = Status}) ->
    case evoq_bit_flags:has(Status, ?REGISTERED) of
        false ->
            {error, connector_not_found};
        true ->
            case evoq_bit_flags:has(Status, ?REVOKED) of
                false ->
                    {ok, Cmd} = revoke_connector_v1:from_map(Payload),
                    convert_events(
                        maybe_revoke_connector:handle(Cmd),
                        fun connector_revoked_v1:to_map/1);
                true ->
                    {error, connector_already_revoked}
            end
    end.

execute_activate(Payload, #connector_state{status = Status}) ->
    case evoq_bit_flags:has(Status, ?REGISTERED) of
        false ->
            {error, connector_not_found};
        true ->
            case evoq_bit_flags:has(Status, ?REVOKED) of
                false ->
                    {ok, Cmd} = activate_connector_v1:from_map(Payload),
                    convert_events(
                        maybe_activate_connector:handle(Cmd),
                        fun connector_activated_v1:to_map/1);
                true ->
                    {error, connector_revoked}
            end
    end.

execute_suspend(Payload, #connector_state{status = Status}) ->
    case evoq_bit_flags:has(Status, ?REGISTERED) of
        false ->
            {error, connector_not_found};
        true ->
            case evoq_bit_flags:has(Status, ?REVOKED) of
                false ->
                    {ok, Cmd} = suspend_connector_v1:from_map(Payload),
                    convert_events(
                        maybe_suspend_connector:handle(Cmd),
                        fun connector_suspended_v1:to_map/1);
                true ->
                    {error, connector_revoked}
            end
    end.

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
apply_event(#{event_type := <<"connector_registered_v1">>} = E, State) ->
    State#connector_state{
        connector_id = maps:get(connector_id, E),
        name = maps:get(name, E),
        socket_path = maps:get(socket_path, E),
        allowed_routes = maps:get(allowed_routes, E, all),
        status = ?REGISTERED bor ?ACTIVE,
        metadata = maps:get(metadata, E, #{})
    };
apply_event(#{event_type := <<"connector_revoked_v1">>}, State) ->
    S0 = evoq_bit_flags:unset(State#connector_state.status, ?ACTIVE),
    State#connector_state{
        status = evoq_bit_flags:set(S0, ?REVOKED)
    };
apply_event(#{event_type := <<"connector_activated_v1">>}, State) ->
    S0 = evoq_bit_flags:unset(State#connector_state.status, ?SUSPENDED),
    State#connector_state{
        status = evoq_bit_flags:set(S0, ?ACTIVE)
    };
apply_event(#{event_type := <<"connector_suspended_v1">>}, State) ->
    S0 = evoq_bit_flags:unset(State#connector_state.status, ?ACTIVE),
    State#connector_state{
        status = evoq_bit_flags:set(S0, ?SUSPENDED)
    };
apply_event(_EventMap, State) ->
    State.
