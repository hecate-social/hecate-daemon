%%% @doc receive_license_rewrap_v1 command.
%%%
%%% Recipient-local. Dispatched by `listen_for_license_rewrapped` (live)
%%% and by `catch_up_realm_licenses` (after reconnect). Updates the
%%% stored `wrapped_cek` + `k_realm_version` on the recipient aggregate.
%%% The plaintext CEK (sealed locally as `accepted_cek_sealed`) is
%%% untouched — rewrap is a metadata-only update for audit / replay.
%%% @end
-module(receive_license_rewrap_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_license_id/1]).

-record(receive_license_rewrap_v1, {
    license_id          :: binary(),
    new_wrapped_cek     :: binary(),
    new_k_realm_version :: pos_integer(),
    batch_id            :: binary() | undefined,
    rewrapped_at        :: integer() | undefined
}).

-opaque receive_license_rewrap_v1() :: #receive_license_rewrap_v1{}.
-export_type([receive_license_rewrap_v1/0]).

command_type() -> receive_license_rewrap_v1.

-spec new(map()) -> {ok, receive_license_rewrap_v1()} | {error, term()}.
new(#{license_id := L,
      new_wrapped_cek := WC,
      new_k_realm_version := V} = P) ->
    {ok, #receive_license_rewrap_v1{
        license_id          = L,
        new_wrapped_cek     = WC,
        new_k_realm_version = V,
        batch_id            = maps:get(batch_id, P, undefined),
        rewrapped_at        = maps:get(rewrapped_at, P, undefined)}};
new(_) ->
    {error, missing_fields}.

-spec get_license_id(receive_license_rewrap_v1()) -> binary().
get_license_id(#receive_license_rewrap_v1{license_id = L}) -> L.

-spec to_map(receive_license_rewrap_v1()) -> map().
to_map(#receive_license_rewrap_v1{} = C) ->
    #{license_id          => C#receive_license_rewrap_v1.license_id,
      new_wrapped_cek     => C#receive_license_rewrap_v1.new_wrapped_cek,
      new_k_realm_version => C#receive_license_rewrap_v1.new_k_realm_version,
      batch_id            => C#receive_license_rewrap_v1.batch_id,
      rewrapped_at        => C#receive_license_rewrap_v1.rewrapped_at}.

-spec from_map(map()) -> {ok, receive_license_rewrap_v1()} | {error, term()}.
from_map(Map) -> new(Map).
