%%% @doc license_rewrapped_v1 domain event.
%%%
%%% Issuer-local event on `issued-license-{id}` stream. Also picked up
%%% by `license_rewrapped_v1_to_batch` which forwards to
%%% `licenses_rewrapped_batch_emitter` for batched mesh publication on
%%% `{realm}.licenses.rewrapped_batch`.
%%%
%%% The event carries realm/issuer context so the batched FACT can be
%%% assembled without re-consulting state. The state module's fold
%%% reads `new_wrapped_cek` / `new_k_realm_version` — extra fields are
%%% silently ignored.
%%% @end
-module(license_rewrapped_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(license_rewrapped_v1, {
    license_id          :: binary(),
    grantee             :: binary() | undefined,
    realm               :: binary() | undefined,
    issuer_did          :: binary() | undefined,
    new_wrapped_cek     :: binary(),
    new_k_realm_version :: pos_integer(),
    batch_id            :: binary(),
    rewrapped_at        :: integer()
}).

-opaque license_rewrapped_v1() :: #license_rewrapped_v1{}.
-export_type([license_rewrapped_v1/0]).

event_type() -> <<"license_rewrapped_v1">>.

-spec new(map()) -> {ok, license_rewrapped_v1()} | {error, term()}.
new(#{license_id := L,
      new_wrapped_cek := WC,
      new_k_realm_version := V,
      batch_id := BId} = P) ->
    {ok, #license_rewrapped_v1{
        license_id          = L,
        grantee             = maps:get(grantee, P, undefined),
        realm               = maps:get(realm, P, undefined),
        issuer_did          = maps:get(issuer_did, P, undefined),
        new_wrapped_cek     = WC,
        new_k_realm_version = V,
        batch_id            = BId,
        rewrapped_at        = maps:get(rewrapped_at, P, erlang:system_time(millisecond))}};
new(_) ->
    {error, missing_fields}.

-spec to_map(license_rewrapped_v1()) -> map().
to_map(#license_rewrapped_v1{} = E) ->
    #{event_type          => event_type(),
      license_id          => E#license_rewrapped_v1.license_id,
      grantee             => E#license_rewrapped_v1.grantee,
      realm               => E#license_rewrapped_v1.realm,
      issuer_did          => E#license_rewrapped_v1.issuer_did,
      new_wrapped_cek     => E#license_rewrapped_v1.new_wrapped_cek,
      new_k_realm_version => E#license_rewrapped_v1.new_k_realm_version,
      batch_id            => E#license_rewrapped_v1.batch_id,
      rewrapped_at        => E#license_rewrapped_v1.rewrapped_at}.

-spec from_map(map()) -> {ok, license_rewrapped_v1()} | {error, term()}.
from_map(Map) -> new(Map).
