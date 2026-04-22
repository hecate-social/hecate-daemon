%%% @doc license_rewrap_received_v1 domain event.
%%%
%%% Recipient-local event on `accepted-license-{id}` stream. Audit record
%%% of a remote rewrap being observed + applied. The state fold
%%% (`accepted_license_state:apply_rewrap/2`) updates `wrapped_cek` and
%%% `k_realm_version`; the sealed plaintext CEK is untouched.
%%% @end
-module(license_rewrap_received_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(license_rewrap_received_v1, {
    license_id          :: binary(),
    new_wrapped_cek     :: binary(),
    new_k_realm_version :: pos_integer(),
    batch_id            :: binary() | undefined,
    rewrapped_at        :: integer() | undefined,
    received_at         :: integer()
}).

-opaque license_rewrap_received_v1() :: #license_rewrap_received_v1{}.
-export_type([license_rewrap_received_v1/0]).

event_type() -> <<"license_rewrap_received_v1">>.

-spec new(map()) -> {ok, license_rewrap_received_v1()} | {error, term()}.
new(#{license_id := L,
      new_wrapped_cek := WC,
      new_k_realm_version := V} = P) ->
    {ok, #license_rewrap_received_v1{
        license_id          = L,
        new_wrapped_cek     = WC,
        new_k_realm_version = V,
        batch_id            = maps:get(batch_id, P, undefined),
        rewrapped_at        = maps:get(rewrapped_at, P, undefined),
        received_at         = maps:get(received_at, P, erlang:system_time(millisecond))}};
new(_) ->
    {error, missing_fields}.

-spec to_map(license_rewrap_received_v1()) -> map().
to_map(#license_rewrap_received_v1{} = E) ->
    #{event_type          => event_type(),
      license_id          => E#license_rewrap_received_v1.license_id,
      new_wrapped_cek     => E#license_rewrap_received_v1.new_wrapped_cek,
      new_k_realm_version => E#license_rewrap_received_v1.new_k_realm_version,
      batch_id            => E#license_rewrap_received_v1.batch_id,
      rewrapped_at        => E#license_rewrap_received_v1.rewrapped_at,
      received_at         => E#license_rewrap_received_v1.received_at}.

-spec from_map(map()) -> {ok, license_rewrap_received_v1()} | {error, term()}.
from_map(Map) -> new(Map).
