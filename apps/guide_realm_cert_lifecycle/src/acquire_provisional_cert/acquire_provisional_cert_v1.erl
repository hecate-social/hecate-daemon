%%% @doc acquire_provisional_cert_v1 command.
%%%
%%% Bootstrap-initiated: "fetch a provisional cert from the realm at
%%% `RealmUrl' using the local public key, and store the bundle under
%%% `CertDir'." Carries no agent payload — the daemon's bootstrap
%%% worker constructs this on first boot.
%%% @end
-module(acquire_provisional_cert_v1).
-behaviour(evoq_command).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([command_type/0]).

-record(acquire_provisional_cert_v1, {
    realm_url    :: binary(),
    cert_dir     :: binary(),
    requested_at :: integer()
}).

-opaque acquire_provisional_cert_v1() :: #acquire_provisional_cert_v1{}.
-export_type([acquire_provisional_cert_v1/0]).

command_type() -> acquire_provisional_cert_v1.

-spec new(map()) -> {ok, acquire_provisional_cert_v1()} | {error, term()}.
new(#{realm_url := U, cert_dir := D, requested_at := R})
  when is_binary(U), is_binary(D), is_integer(R) ->
    {ok, #acquire_provisional_cert_v1{realm_url = U, cert_dir = D, requested_at = R}};
new(#{realm_url := U, cert_dir := D}) when is_binary(U), is_binary(D) ->
    {ok, new(U, D, erlang:system_time(millisecond))};
new(_) ->
    {error, missing_fields}.

-spec new(binary(), binary(), integer()) -> acquire_provisional_cert_v1().
new(RealmUrl, CertDir, RequestedAt)
  when is_binary(RealmUrl), is_binary(CertDir), is_integer(RequestedAt) ->
    #acquire_provisional_cert_v1{realm_url = RealmUrl, cert_dir = CertDir,
                                 requested_at = RequestedAt}.

-spec to_map(acquire_provisional_cert_v1()) -> map().
to_map(#acquire_provisional_cert_v1{realm_url = U, cert_dir = D, requested_at = R}) ->
    #{realm_url => U, cert_dir => D, requested_at => R}.

-spec from_map(map()) -> {ok, acquire_provisional_cert_v1()} | {error, term()}.
from_map(#{realm_url := U, cert_dir := D, requested_at := R})
  when is_binary(U), is_binary(D), is_integer(R) ->
    {ok, #acquire_provisional_cert_v1{realm_url = U, cert_dir = D, requested_at = R}};
from_map(_) ->
    {error, invalid_acquire_provisional_cert_command}.
