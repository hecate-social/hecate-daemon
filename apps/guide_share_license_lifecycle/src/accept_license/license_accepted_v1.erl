%%% @doc license_accepted_v1 domain event.
%%%
%%% Recipient-local event. Carries `accepted_cek_sealed` — plaintext
%%% CEK re-sealed via `hecate_crypto` for later open-path use. Also
%%% carries the original license fields so aggregate replay can
%%% reconstruct state without consulting other stores.
%%% @end
-module(license_accepted_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(license_accepted_v1, {
    license_id          :: binary(),
    file_id             :: binary(),
    grantee             :: binary(),
    wrap_strategy       :: atom(),
    wrapped_cek         :: binary(),
    accepted_cek_sealed :: binary(),
    k_realm_version     :: non_neg_integer() | undefined,
    issuer_did          :: binary(),
    realm               :: binary(),
    issued_at           :: integer(),
    accepted_at         :: integer(),
    expires_at          :: integer()
}).

-opaque license_accepted_v1() :: #license_accepted_v1{}.
-export_type([license_accepted_v1/0]).

event_type() -> <<"license_accepted_v1">>.

-spec new(map()) -> {ok, license_accepted_v1()} | {error, term()}.
new(#{license_id := LId, file_id := FId, grantee := G,
      wrap_strategy := WS, wrapped_cek := WC,
      accepted_cek_sealed := ACS,
      issuer_did := Issuer, realm := Realm,
      issued_at := IA, accepted_at := AA,
      expires_at := EA} = P) ->
    {ok, #license_accepted_v1{
        license_id          = LId,
        file_id             = FId,
        grantee             = G,
        wrap_strategy       = WS,
        wrapped_cek         = WC,
        accepted_cek_sealed = ACS,
        k_realm_version     = maps:get(k_realm_version, P, undefined),
        issuer_did          = Issuer,
        realm               = Realm,
        issued_at           = IA,
        accepted_at         = AA,
        expires_at          = EA}};
new(_) ->
    {error, missing_fields}.

-spec to_map(license_accepted_v1()) -> map().
to_map(#license_accepted_v1{} = E) ->
    #{event_type          => event_type(),
      license_id          => E#license_accepted_v1.license_id,
      file_id             => E#license_accepted_v1.file_id,
      grantee             => E#license_accepted_v1.grantee,
      wrap_strategy       => E#license_accepted_v1.wrap_strategy,
      wrapped_cek         => E#license_accepted_v1.wrapped_cek,
      accepted_cek_sealed => E#license_accepted_v1.accepted_cek_sealed,
      k_realm_version     => E#license_accepted_v1.k_realm_version,
      issuer_did          => E#license_accepted_v1.issuer_did,
      realm               => E#license_accepted_v1.realm,
      issued_at           => E#license_accepted_v1.issued_at,
      accepted_at         => E#license_accepted_v1.accepted_at,
      expires_at          => E#license_accepted_v1.expires_at}.

-spec from_map(map()) -> {ok, license_accepted_v1()} | {error, term()}.
from_map(Map) -> new(Map).
