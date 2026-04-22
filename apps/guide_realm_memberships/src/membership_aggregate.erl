%%% @doc Aggregate for realm membership lifecycle.
%%%
%%% Each realm membership is an independent aggregate.
%%% Stream: realmmembership-{uuid}.
%%% Lifecycle: initiate -> confirm -> revoke.
-module(membership_aggregate).
-behaviour(evoq_aggregate).

-include("membership_state.hrl").
-include("membership_status.hrl").

%% Behaviour callbacks
-export([init/1, execute/2, apply/2]).

%% State module + stream routing
-export([state_module/0, stream_id/1]).

-spec state_module() -> module().
state_module() -> membership_state.

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

init(AggregateId) ->
    {ok, membership_state:new(AggregateId)}.

-spec stream_id(binary()) -> binary().
stream_id(MembershipId) ->
    <<"realmmembership-", MembershipId/binary>>.

%% @doc Execute command — State FIRST (evoq convention).
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%% @doc Apply event — State FIRST. Delegates to state module.
apply(State, Event) ->
    membership_state:apply_event(State, Event).

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(initiate_realm_membership, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_INITIATED of
        0 -> maybe_initiate_realm_membership:handle_from_map(Payload);
        _ -> {error, already_initiated}
    end;

do_execute(confirm_realm_membership, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_INITIATED of
        0 -> {error, not_initiated};
        _ ->
            case State#membership_state.status band ?MEMBERSHIP_CONFIRMED of
                0 -> maybe_confirm_realm_membership:handle_from_map(Payload);
                _ -> {error, already_confirmed}
            end
    end;

do_execute(secure_realm_credentials, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_CONFIRMED of
        0 -> {error, not_confirmed};
        _ ->
            case State#membership_state.status band ?CREDENTIALS_SECURED of
                0 -> maybe_secure_realm_credentials:handle_from_map(Payload);
                _ -> {error, credentials_already_secured}
            end
    end;

do_execute(end_realm_membership_v1, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_CONFIRMED of
        0 -> {error, not_confirmed};
        _ ->
            case State#membership_state.status band ?MEMBERSHIP_ENDED of
                0 -> maybe_end_realm_membership:handle_from_map(Payload);
                _ -> {error, already_ended}
            end
    end;

do_execute(resign_realm_membership_v1, State, Payload) ->
    case State#membership_state.status band ?MEMBERSHIP_CONFIRMED of
        0 -> {error, not_confirmed};
        _ ->
            case State#membership_state.status band ?MEMBERSHIP_ENDED of
                0 -> maybe_resign_realm_membership:handle_from_map(
                         enrich_resign(Payload, State));
                _ -> {error, already_ended}
            end
    end;

do_execute(store_realm_shared_key, State, Payload) ->
    %% Acceptable once the realm is confirmed and not ended. Re-storing is
    %% permitted — that's how rotation lands (new version, new bytes).
    Confirmed = (State#membership_state.status band ?MEMBERSHIP_CONFIRMED) =/= 0,
    Ended     = (State#membership_state.status band ?MEMBERSHIP_ENDED)     =/= 0,
    case {Confirmed, Ended} of
        {false, _}    -> {error, not_confirmed};
        {true,  true} -> {error, membership_ended};
        {true,  false} -> maybe_store_realm_shared_key:handle_from_map(Payload)
    end;

do_execute(announce_identity_public_key, State, Payload) ->
    %% Announce once K_realm is stored (full membership). Idempotent —
    %% re-announcing is a no-op because the aggregate rejects it.
    KeyStored = (State#membership_state.status band ?REALM_KEY_STORED) =/= 0,
    Announced = (State#membership_state.status band ?IDENTITY_PUBKEY_ANNOUNCED) =/= 0,
    Ended     = (State#membership_state.status band ?MEMBERSHIP_ENDED) =/= 0,
    case {KeyStored, Announced, Ended} of
        {false, _,    _}    -> {error, realm_key_not_stored};
        {_,     _,    true} -> {error, membership_ended};
        {true,  true, _}    -> {error, already_announced};
        {true,  false, false} -> maybe_announce_identity_public_key:handle_from_map(Payload)
    end;

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

%% @private Enrich resign payload with realm_id + member_did (own MRI)
%% already present on the aggregate, so the emitter and terminal event
%% can reference them without the caller needing to know.
enrich_resign(Payload, #membership_state{} = S) ->
    MemberDid = case erlang:whereis(hecate_identity) of
        undefined -> undefined;
        _ -> case hecate_identity:get_mri() of
                 {ok, Mri}       -> Mri;
                 not_initialized -> undefined
             end
    end,
    Defaults = #{
        realm_id   => S#membership_state.realm_id,
        member_did => MemberDid
    },
    maps:merge(Defaults, Payload).
