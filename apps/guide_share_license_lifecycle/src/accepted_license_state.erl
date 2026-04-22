%%% @doc Recipient-side share-license state module.
%%%
%%% Owns the `#accepted_license_state{}` record shape and event folding.
%%% Stream: `accepted-license-{license_id}`. Store: `share_licenses_store`.
%%% @end
-module(accepted_license_state).
-behaviour(evoq_state).

-include("share_license_status.hrl").
-include("accepted_license_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #accepted_license_state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(_AggregateId) ->
    #accepted_license_state{status = 0}.

-spec apply_event(state(), map()) -> state().
apply_event(S, #{event_type := <<"license_accepted_v1">>} = E)         -> apply_accepted(E, S);
apply_event(S, #{event_type := <<"license_ended_v1">>} = E)            -> apply_ended(E, S);
apply_event(S, #{event_type := <<"license_rewrap_received_v1">>} = E)  -> apply_rewrap(E, S);
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#accepted_license_state{} = S) ->
    #{license_id          => S#accepted_license_state.license_id,
      file_id             => S#accepted_license_state.file_id,
      grantee             => S#accepted_license_state.grantee,
      wrap_strategy       => S#accepted_license_state.wrap_strategy,
      wrapped_cek         => S#accepted_license_state.wrapped_cek,
      accepted_cek_sealed => S#accepted_license_state.accepted_cek_sealed,
      k_realm_version     => S#accepted_license_state.k_realm_version,
      issuer_did          => S#accepted_license_state.issuer_did,
      realm               => S#accepted_license_state.realm,
      issued_at           => S#accepted_license_state.issued_at,
      accepted_at         => S#accepted_license_state.accepted_at,
      ended_at            => S#accepted_license_state.ended_at,
      end_reason          => S#accepted_license_state.end_reason,
      expires_at          => S#accepted_license_state.expires_at,
      status              => S#accepted_license_state.status}.

%% --- Apply helpers ---

apply_accepted(E, State) ->
    Data = event_data(E),
    NewStatus = evoq_bit_flags:set(
        evoq_bit_flags:set(0, ?SL_ACCEPTED),
        ?SL_CEK_USABLE),
    State#accepted_license_state{
        license_id          = gf(license_id,          Data),
        file_id             = gf(file_id,             Data),
        grantee             = gf(grantee,             Data),
        wrap_strategy       = to_atom(gf(wrap_strategy, Data)),
        wrapped_cek         = gf(wrapped_cek,         Data),
        accepted_cek_sealed = gf(accepted_cek_sealed, Data),
        k_realm_version     = gf(k_realm_version,     Data),
        issuer_did          = gf(issuer_did,          Data),
        realm               = gf(realm,               Data),
        issued_at           = gf(issued_at,           Data),
        expires_at          = gf(expires_at,          Data),
        accepted_at         = gf(accepted_at,         Data, erlang:system_time(millisecond)),
        status              = NewStatus}.

apply_ended(E, #accepted_license_state{status = S} = State) ->
    Data = event_data(E),
    Cleared = evoq_bit_flags:unset(S, ?SL_CEK_USABLE),
    State#accepted_license_state{
        status     = evoq_bit_flags:set(Cleared, ?SL_ENDED),
        ended_at   = gf(ended_at, Data, erlang:system_time(millisecond)),
        end_reason = to_atom(gf(reason, Data))}.

apply_rewrap(E, #accepted_license_state{status = S} = State) ->
    Data = event_data(E),
    State#accepted_license_state{
        status          = evoq_bit_flags:set(S, ?SL_REWRAPPED),
        wrapped_cek     = gf(new_wrapped_cek,     Data, State#accepted_license_state.wrapped_cek),
        k_realm_version = gf(new_k_realm_version, Data, State#accepted_license_state.k_realm_version)}.

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
