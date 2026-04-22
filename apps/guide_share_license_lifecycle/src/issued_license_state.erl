%%% @doc Issuer-side share-license state module.
%%%
%%% Owns the `#issued_license_state{}` record shape and event folding.
%%% Stream: `issued-license-{license_id}`. Store: `share_licenses_store`.
%%% @end
-module(issued_license_state).
-behaviour(evoq_state).

-include("share_license_status.hrl").
-include("issued_license_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #issued_license_state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(_AggregateId) ->
    #issued_license_state{status = 0}.

-spec apply_event(state(), map()) -> state().
apply_event(S, #{event_type := <<"license_issued_v1">>} = E)           -> apply_issued(E, S);
apply_event(S, #{event_type := <<"share_license_revoked_v1">>} = E)    -> apply_revoked(E, S);
apply_event(S, #{event_type := <<"license_rewrapped_v1">>} = E)        -> apply_rewrapped(E, S);
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#issued_license_state{} = S) ->
    #{license_id        => S#issued_license_state.license_id,
      file_id           => S#issued_license_state.file_id,
      grantee           => S#issued_license_state.grantee,
      wrap_strategy     => S#issued_license_state.wrap_strategy,
      wrapped_cek       => S#issued_license_state.wrapped_cek,
      origin_cek_sealed => S#issued_license_state.origin_cek_sealed,
      k_realm_version   => S#issued_license_state.k_realm_version,
      issuer_did        => S#issued_license_state.issuer_did,
      realm             => S#issued_license_state.realm,
      batch_id          => S#issued_license_state.batch_id,
      issued_at         => S#issued_license_state.issued_at,
      expires_at        => S#issued_license_state.expires_at,
      revoked_at        => S#issued_license_state.revoked_at,
      revoke_reason     => S#issued_license_state.revoke_reason,
      rewrapped_at      => S#issued_license_state.rewrapped_at,
      status            => S#issued_license_state.status}.

%% --- Apply helpers ---

apply_issued(E, State) ->
    Data = event_data(E),
    State#issued_license_state{
        license_id        = gf(license_id,        Data),
        file_id           = gf(file_id,           Data),
        grantee           = gf(grantee,           Data),
        wrap_strategy     = to_atom(gf(wrap_strategy, Data)),
        wrapped_cek       = gf(wrapped_cek,       Data),
        origin_cek_sealed = gf(origin_cek_sealed, Data),
        k_realm_version   = gf(k_realm_version,   Data),
        issuer_did        = gf(issuer_did,        Data),
        realm             = gf(realm,             Data),
        batch_id          = gf(batch_id,          Data),
        issued_at         = gf(issued_at,         Data),
        expires_at        = gf(expires_at,        Data),
        status            = evoq_bit_flags:set(0, ?SL_ISSUED)}.

apply_revoked(E, #issued_license_state{status = S} = State) ->
    Data = event_data(E),
    State#issued_license_state{
        status        = evoq_bit_flags:set(S, ?SL_REVOKED),
        revoked_at    = gf(revoked_at, Data, erlang:system_time(millisecond)),
        revoke_reason = to_atom(gf(reason, Data))}.

apply_rewrapped(E, #issued_license_state{status = S} = State) ->
    Data = event_data(E),
    State#issued_license_state{
        status          = evoq_bit_flags:set(S, ?SL_REWRAPPED),
        wrapped_cek     = gf(new_wrapped_cek,     Data, State#issued_license_state.wrapped_cek),
        k_realm_version = gf(new_k_realm_version, Data, State#issued_license_state.k_realm_version),
        rewrapped_at    = gf(rewrapped_at,        Data, erlang:system_time(millisecond))}.

%% --- Internal ---

event_data(#{data := D}) when is_map(D) -> D;
event_data(E) when is_map(E) -> E.

gf(K, M) -> gf(K, M, undefined).
gf(K, M, Default) ->
    case maps:find(K, M) of
        {ok, V} -> V;
        error ->
            case is_atom(K) of
                true  -> maps:get(atom_to_binary(K, utf8), M, Default);
                false -> Default
            end
    end.

to_atom(A) when is_atom(A) -> A;
to_atom(B) when is_binary(B) -> binary_to_atom(B, utf8);
to_atom(undefined) -> undefined.
