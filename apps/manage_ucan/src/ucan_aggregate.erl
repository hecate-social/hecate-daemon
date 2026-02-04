%%% @doc UCAN aggregate
%%% Maintains capability token state.
-module(ucan_aggregate).

-export([initial_state/0, execute/2, apply_event/2]).

-record(ucan_state, {
    capability_id :: binary() | undefined,
    issuer :: binary() | undefined,
    audience :: binary() | undefined,
    resource :: binary() | undefined,
    actions :: [binary()],
    expires_at :: integer() | undefined,
    granted_at :: integer() | undefined,
    revoked :: boolean(),
    revoked_at :: integer() | undefined
}).

-opaque ucan_state() :: #ucan_state{}.
-export_type([ucan_state/0]).

%% @doc Initial empty state for evoq.
-spec initial_state() -> ucan_state().
initial_state() ->
    #ucan_state{
        capability_id = undefined,
        issuer = undefined,
        audience = undefined,
        resource = undefined,
        actions = [],
        expires_at = undefined,
        granted_at = undefined,
        revoked = false,
        revoked_at = undefined
    }.

%% @doc Execute command against aggregate state (evoq callback).
-spec execute(map(), ucan_state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := grant_capability} = Payload, State) ->
    case State#ucan_state.granted_at of
        undefined ->
            {ok, Cmd} = grant_capability_v1:from_map(Payload),
            execute_handler(maybe_grant_capability:handle(Cmd));
        _ ->
            {error, capability_already_granted}
    end;
execute(#{command_type := revoke_capability} = Payload, State) ->
    case {State#ucan_state.granted_at, State#ucan_state.revoked} of
        {undefined, _} ->
            {error, capability_not_granted};
        {_, true} ->
            {error, capability_already_revoked};
        {_, false} ->
            %% Verify revoker has authority (must be the original issuer)
            Revoker = maps:get(revoker, Payload),
            Issuer = State#ucan_state.issuer,
            case Revoker =:= Issuer of
                true ->
                    {ok, Cmd} = revoke_capability_v1:from_map(Payload),
                    execute_handler(maybe_revoke_capability:handle(Cmd));
                false ->
                    {error, not_authorized_to_revoke}
            end
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
-spec apply_event(map(), ucan_state()) -> ucan_state().
apply_event(#{
    event_type := <<"capability_granted_v1">>,
    capability_id := CapId,
    issuer := Issuer,
    audience := Audience,
    resource := Resource,
    actions := Actions,
    expires_at := ExpiresAt,
    granted_at := GrantedAt
}, Agg) ->
    Agg#ucan_state{
        capability_id = CapId,
        issuer = Issuer,
        audience = Audience,
        resource = Resource,
        actions = Actions,
        expires_at = ExpiresAt,
        granted_at = GrantedAt
    };

apply_event(#{
    event_type := <<"capability_revoked_v1">>,
    revoked_at := RevokedAt
}, Agg) ->
    Agg#ucan_state{
        revoked = true,
        revoked_at = RevokedAt
    };

apply_event(_OtherEvent, Agg) ->
    Agg.
