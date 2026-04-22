%%% @doc accept_license_v1 command.
%%%
%%% Dispatched by `listen_for_license_batch` (live) or
%%% `catch_up_realm_licenses` (Session 3) once per batch entry that
%%% matches this daemon's DID.
%%% @end
-module(accept_license_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_license_id/1]).

-record(accept_license_v1, {
    license_id      :: binary(),
    file_id         :: binary(),
    grantee         :: binary(),
    wrap_strategy   :: atom(),
    wrapped_cek     :: binary(),
    k_realm_version :: non_neg_integer() | undefined,
    issuer_did      :: binary(),
    realm           :: binary(),
    issued_at       :: integer(),
    expires_at      :: integer()
}).

-opaque accept_license_v1() :: #accept_license_v1{}.
-export_type([accept_license_v1/0]).

command_type() -> accept_license_v1.

-spec new(map()) -> {ok, accept_license_v1()} | {error, term()}.
new(#{license_id := LId, file_id := FId, grantee := G,
      wrap_strategy := WS, wrapped_cek := WC,
      issuer_did := Issuer, realm := Realm,
      issued_at := IA, expires_at := EA} = P) ->
    {ok, #accept_license_v1{
        license_id      = LId,
        file_id         = FId,
        grantee         = G,
        wrap_strategy   = WS,
        wrapped_cek     = WC,
        k_realm_version = maps:get(k_realm_version, P, undefined),
        issuer_did      = Issuer,
        realm           = Realm,
        issued_at       = IA,
        expires_at      = EA}};
new(_) ->
    {error, missing_fields}.

-spec get_license_id(accept_license_v1()) -> binary().
get_license_id(#accept_license_v1{license_id = L}) -> L.

-spec to_map(accept_license_v1()) -> map().
to_map(#accept_license_v1{} = C) ->
    #{license_id      => C#accept_license_v1.license_id,
      file_id         => C#accept_license_v1.file_id,
      grantee         => C#accept_license_v1.grantee,
      wrap_strategy   => C#accept_license_v1.wrap_strategy,
      wrapped_cek     => C#accept_license_v1.wrapped_cek,
      k_realm_version => C#accept_license_v1.k_realm_version,
      issuer_did      => C#accept_license_v1.issuer_did,
      realm           => C#accept_license_v1.realm,
      issued_at       => C#accept_license_v1.issued_at,
      expires_at      => C#accept_license_v1.expires_at}.

-spec from_map(map()) -> {ok, accept_license_v1()} | {error, term()}.
from_map(Map) -> new(Map).
