%%% @doc license_issued_v1 domain event.
%%%
%%% Stored on issuer's aggregate stream. Also picked up by the batched
%%% mesh emitter (`licenses_issued_batch_emitter`) which collapses
%%% N events sharing a `batch_id` into a single FACT on
%%% `{realm}.licenses.issued_batch`.
%%% @end
-module(license_issued_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(license_issued_v1, {
    license_id        :: binary(),
    file_id           :: binary(),
    grantee           :: binary(),
    wrap_strategy     :: atom(),
    wrapped_cek       :: binary(),
    origin_cek_sealed :: binary(),
    k_realm_version   :: non_neg_integer() | undefined,
    issuer_did        :: binary(),
    realm             :: binary(),
    batch_id          :: binary(),
    issued_at         :: integer(),
    expires_at        :: integer()
}).

-opaque license_issued_v1() :: #license_issued_v1{}.
-export_type([license_issued_v1/0]).

event_type() -> <<"license_issued_v1">>.

-spec new(map()) -> {ok, license_issued_v1()} | {error, term()}.
new(#{license_id := LId, file_id := FId, grantee := G,
      wrap_strategy := WS, wrapped_cek := WC,
      origin_cek_sealed := OCS,
      issuer_did := Issuer, realm := Realm,
      batch_id := BId, issued_at := IA, expires_at := EA} = P) ->
    {ok, #license_issued_v1{
        license_id        = LId,
        file_id           = FId,
        grantee           = G,
        wrap_strategy     = WS,
        wrapped_cek       = WC,
        origin_cek_sealed = OCS,
        k_realm_version   = maps:get(k_realm_version, P, undefined),
        issuer_did        = Issuer,
        realm             = Realm,
        batch_id          = BId,
        issued_at         = IA,
        expires_at        = EA}};
new(_) ->
    {error, missing_fields}.

-spec to_map(license_issued_v1()) -> map().
to_map(#license_issued_v1{} = E) ->
    #{event_type        => event_type(),
      license_id        => E#license_issued_v1.license_id,
      file_id           => E#license_issued_v1.file_id,
      grantee           => E#license_issued_v1.grantee,
      wrap_strategy     => E#license_issued_v1.wrap_strategy,
      wrapped_cek       => E#license_issued_v1.wrapped_cek,
      origin_cek_sealed => E#license_issued_v1.origin_cek_sealed,
      k_realm_version   => E#license_issued_v1.k_realm_version,
      issuer_did        => E#license_issued_v1.issuer_did,
      realm             => E#license_issued_v1.realm,
      batch_id          => E#license_issued_v1.batch_id,
      issued_at         => E#license_issued_v1.issued_at,
      expires_at        => E#license_issued_v1.expires_at}.

-spec from_map(map()) -> {ok, license_issued_v1()} | {error, term()}.
from_map(Map) -> new(Map).
