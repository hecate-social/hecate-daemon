%%% @doc State module for realm membership aggregate.
%%%
%%% Owns the state record, event folding, and serialization.
%%% @end
-module(membership_state).

-behaviour(evoq_state).

-include("membership_state.hrl").
-include("membership_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #membership_state{}.
-export_type([state/0]).

%% @doc Create initial empty state.
-spec new(binary()) -> state().
new(_AggregateId) ->
    #membership_state{
        membership_id = undefined,
        realm_id = undefined,
        realm_url = undefined,
        oauth_account = undefined,
        oauth_provider = undefined,
        encrypted_credentials = undefined,
        initiated_at = undefined,
        confirmed_at = undefined,
        revoked_at = undefined,
        secured_at = undefined,
        k_realm_version = undefined,
        k_realm_encrypted = undefined,
        k_realm_received_at = undefined,
        identity_pubkey_announced_at = undefined,
        ended_at = undefined,
        end_reason = undefined,
        ended_by = undefined,
        resigned_at = undefined,
        status = 0
    }.

%% @doc Apply event to state. State FIRST, Event SECOND.
-spec apply_event(state(), map()) -> state().
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% @doc Serialize state to map.
-spec to_map(state()) -> map().
to_map(#membership_state{} = S) ->
    #{
        membership_id         => S#membership_state.membership_id,
        realm_id              => S#membership_state.realm_id,
        realm_url             => S#membership_state.realm_url,
        oauth_account         => S#membership_state.oauth_account,
        oauth_provider        => S#membership_state.oauth_provider,
        encrypted_credentials => S#membership_state.encrypted_credentials,
        initiated_at          => S#membership_state.initiated_at,
        confirmed_at          => S#membership_state.confirmed_at,
        revoked_at            => S#membership_state.revoked_at,
        secured_at            => S#membership_state.secured_at,
        k_realm_version       => S#membership_state.k_realm_version,
        k_realm_encrypted     => S#membership_state.k_realm_encrypted,
        k_realm_received_at   => S#membership_state.k_realm_received_at,
        identity_pubkey_announced_at =>
            S#membership_state.identity_pubkey_announced_at,
        ended_at              => S#membership_state.ended_at,
        end_reason            => S#membership_state.end_reason,
        ended_by              => S#membership_state.ended_by,
        resigned_at           => S#membership_state.resigned_at,
        status                => S#membership_state.status
    }.

%% ===================================================================
%% Event application
%% ===================================================================

do_apply(<<"realm_membership_initiated_v1">>, State, Event) ->
    State#membership_state{
        membership_id = get_field(<<"membership_id">>, membership_id, Event),
        realm_url = get_field(<<"realm_url">>, realm_url, Event),
        initiated_at = get_field(<<"initiated_at">>, initiated_at, Event),
        status = State#membership_state.status bor ?MEMBERSHIP_INITIATED
    };

do_apply(<<"realm_membership_confirmed_v1">>, State, Event) ->
    State#membership_state{
        realm_id = get_field(<<"realm_id">>, realm_id, Event),
        oauth_account = get_field(<<"oauth_account">>, oauth_account, Event),
        oauth_provider = get_field(<<"oauth_provider">>, oauth_provider, Event),
        confirmed_at = get_field(<<"confirmed_at">>, confirmed_at, Event),
        status = State#membership_state.status bor ?MEMBERSHIP_CONFIRMED
    };

do_apply(<<"realm_credentials_secured_v1">>, State, Event) ->
    State#membership_state{
        encrypted_credentials = get_field(<<"encrypted_credentials">>, encrypted_credentials, Event),
        secured_at = get_field(<<"secured_at">>, secured_at, Event),
        status = State#membership_state.status bor ?CREDENTIALS_SECURED
    };

%% Historical event — pre-Phase-D streams stored
%% `realm_membership_revoked_v1`. Upcast on replay so state carries the
%% new end-of-life fields while retaining MEMBERSHIP_REVOKED for audit.
do_apply(<<"realm_membership_revoked_v1">>, State, Event) ->
    At = get_field(<<"revoked_at">>, revoked_at, Event),
    State#membership_state{
        revoked_at = At,
        ended_at   = At,
        end_reason = revoked,
        status     = State#membership_state.status
                         bor ?MEMBERSHIP_REVOKED
                         bor ?MEMBERSHIP_ENDED
    };

do_apply(<<"realm_membership_ended_v1">>, State, Event) ->
    At = get_field(<<"ended_at">>, ended_at, Event),
    Reason = normalize_reason(get_field(<<"reason">>, reason, Event)),
    EndedBy = get_field(<<"ended_by">>, ended_by, Event),
    Status0 = State#membership_state.status bor ?MEMBERSHIP_ENDED,
    Status = case Reason of
        revoked -> Status0 bor ?MEMBERSHIP_REVOKED;
        _       -> Status0
    end,
    State#membership_state{
        ended_at   = At,
        end_reason = Reason,
        ended_by   = EndedBy,
        revoked_at = revoked_timestamp(State#membership_state.revoked_at,
                                        Reason, At),
        status     = Status
    };

do_apply(<<"realm_membership_resigned_v1">>, State, Event) ->
    At = get_field(<<"resigned_at">>, resigned_at, Event),
    State#membership_state{
        resigned_at = At,
        status      = State#membership_state.status bor ?MEMBERSHIP_RESIGNED
    };

do_apply(<<"realm_shared_key_stored_v1">>, State, Event) ->
    State#membership_state{
        k_realm_version     = get_field(<<"k_realm_version">>, k_realm_version, Event),
        k_realm_encrypted   = get_field(<<"k_realm_encrypted">>, k_realm_encrypted, Event),
        k_realm_received_at = get_field(<<"received_at">>, received_at, Event),
        status              = State#membership_state.status bor ?REALM_KEY_STORED
    };

do_apply(<<"identity_public_key_announced_v1">>, State, Event) ->
    State#membership_state{
        identity_pubkey_announced_at =
            get_field(<<"announced_at">>, announced_at, Event),
        status = State#membership_state.status bor ?IDENTITY_PUBKEY_ANNOUNCED
    };

do_apply(_UnknownType, State, _Event) ->
    State.

%% ===================================================================
%% Internal
%% ===================================================================

get_field(BinKey, AtomKey, Event) ->
    maps:get(BinKey, Event, maps:get(AtomKey, Event, undefined)).

normalize_reason(A) when is_atom(A) -> A;
normalize_reason(B) when is_binary(B) ->
    try binary_to_existing_atom(B, utf8)
    catch _:_ -> revoked
    end;
normalize_reason(_) -> revoked.

revoked_timestamp(Existing, revoked, At) when Existing =:= undefined -> At;
revoked_timestamp(Existing, _Other,  _At) -> Existing.
