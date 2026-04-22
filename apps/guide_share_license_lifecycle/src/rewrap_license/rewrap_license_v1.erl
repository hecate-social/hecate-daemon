%%% @doc rewrap_license_v1 command.
%%%
%%% Issuer-local. Dispatched by `on_realm_key_rotated_rewrap_licenses`
%%% once per license that needs rewrapping under a new K_realm. Updates
%%% the stored `wrapped_cek` + `k_realm_version` on the issuer aggregate
%%% and emits `license_rewrapped_v1` which the batched mesh emitter
%%% collects into a single `{realm}.licenses.rewrapped_batch` FACT.
%%% @end
-module(rewrap_license_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_license_id/1]).

-record(rewrap_license_v1, {
    license_id          :: binary(),
    new_wrapped_cek     :: binary(),
    new_k_realm_version :: pos_integer(),
    batch_id            :: binary(),
    rewrapped_at        :: integer()
}).

-opaque rewrap_license_v1() :: #rewrap_license_v1{}.
-export_type([rewrap_license_v1/0]).

command_type() -> rewrap_license_v1.

-spec new(map()) -> {ok, rewrap_license_v1()} | {error, term()}.
new(#{license_id := L,
      new_wrapped_cek := WC,
      new_k_realm_version := V,
      batch_id := BId} = P) ->
    At = maps:get(rewrapped_at, P, erlang:system_time(millisecond)),
    {ok, #rewrap_license_v1{
        license_id          = L,
        new_wrapped_cek     = WC,
        new_k_realm_version = V,
        batch_id            = BId,
        rewrapped_at        = At}};
new(_) ->
    {error, missing_fields}.

-spec get_license_id(rewrap_license_v1()) -> binary().
get_license_id(#rewrap_license_v1{license_id = L}) -> L.

-spec to_map(rewrap_license_v1()) -> map().
to_map(#rewrap_license_v1{} = C) ->
    #{license_id          => C#rewrap_license_v1.license_id,
      new_wrapped_cek     => C#rewrap_license_v1.new_wrapped_cek,
      new_k_realm_version => C#rewrap_license_v1.new_k_realm_version,
      batch_id            => C#rewrap_license_v1.batch_id,
      rewrapped_at        => C#rewrap_license_v1.rewrapped_at}.

-spec from_map(map()) -> {ok, rewrap_license_v1()} | {error, term()}.
from_map(Map) -> new(Map).
