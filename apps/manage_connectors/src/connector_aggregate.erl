%%% @doc Connector aggregate
%%% Maintains connector state and applies events.
%%% Status is a bit flag integer: REGISTERED=1, ACTIVE=2, SUSPENDED=4, REVOKED=8
-module(connector_aggregate).

-export([execute/2, apply_event/2, initial_state/0]).

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
-spec execute(map(), state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := <<"revoke_connector">>} = Payload, State) ->
    execute_revoke(Payload, State);
execute(#{command_type := <<"activate_connector">>} = Payload, State) ->
    execute_activate(Payload, State);
execute(#{command_type := <<"suspend_connector">>} = Payload, State) ->
    execute_suspend(Payload, State);
execute(Payload, State) ->
    %% Default: register_connector
    execute_register(Payload, State).

execute_register(Payload, #connector_state{status = Status}) ->
    case Status band ?REGISTERED of
        0 ->
            {ok, Cmd} = register_connector_v1:from_map(Payload),
            convert_events(
                maybe_register_connector:handle(Cmd),
                fun connector_registered_v1:to_map/1);
        _ ->
            {error, connector_already_registered}
    end.

execute_revoke(Payload, #connector_state{status = Status}) ->
    case Status band ?REGISTERED of
        0 ->
            {error, connector_not_found};
        _ ->
            case Status band ?REVOKED of
                0 ->
                    {ok, Cmd} = revoke_connector_v1:from_map(Payload),
                    convert_events(
                        maybe_revoke_connector:handle(Cmd),
                        fun connector_revoked_v1:to_map/1);
                _ ->
                    {error, connector_already_revoked}
            end
    end.

execute_activate(Payload, #connector_state{status = Status}) ->
    case Status band ?REGISTERED of
        0 ->
            {error, connector_not_found};
        _ ->
            case Status band ?REVOKED of
                0 ->
                    {ok, Cmd} = activate_connector_v1:from_map(Payload),
                    convert_events(
                        maybe_activate_connector:handle(Cmd),
                        fun connector_activated_v1:to_map/1);
                _ ->
                    {error, connector_revoked}
            end
    end.

execute_suspend(Payload, #connector_state{status = Status}) ->
    case Status band ?REGISTERED of
        0 ->
            {error, connector_not_found};
        _ ->
            case Status band ?REVOKED of
                0 ->
                    {ok, Cmd} = suspend_connector_v1:from_map(Payload),
                    convert_events(
                        maybe_suspend_connector:handle(Cmd),
                        fun connector_suspended_v1:to_map/1);
                _ ->
                    {error, connector_revoked}
            end
    end.

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

%% @doc Apply event to state (event sourcing)
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
    State#connector_state{
        status = (State#connector_state.status band (bnot ?ACTIVE)) bor ?REVOKED
    };
apply_event(#{event_type := <<"connector_activated_v1">>}, State) ->
    State#connector_state{
        status = (State#connector_state.status band (bnot ?SUSPENDED)) bor ?ACTIVE
    };
apply_event(#{event_type := <<"connector_suspended_v1">>}, State) ->
    State#connector_state{
        status = (State#connector_state.status band (bnot ?ACTIVE)) bor ?SUSPENDED
    };
apply_event(_EventMap, State) ->
    State.
