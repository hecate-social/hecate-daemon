%%% @doc issue_license_v1 command.
%%%
%%% Dispatched by `maybe_share_file` once per recipient when a file is
%%% shared. Carries the per-recipient wrapped CEK and the issuer's
%%% `origin_cek_sealed` copy for later rewrap.
%%% @end
-module(issue_license_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_license_id/1]).

-record(issue_license_v1, {
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

-opaque issue_license_v1() :: #issue_license_v1{}.
-export_type([issue_license_v1/0]).

command_type() -> issue_license_v1.

-spec new(map()) -> {ok, issue_license_v1()} | {error, term()}.
new(#{license_id := LId, file_id := FId, grantee := G,
      wrap_strategy := WS, wrapped_cek := WC,
      origin_cek_sealed := OCS,
      issuer_did := Issuer, realm := Realm,
      batch_id := BId} = P) ->
    Now = erlang:system_time(millisecond),
    IssuedAt  = maps:get(issued_at,  P, Now),
    ExpiresAt = maps:get(expires_at, P, IssuedAt + ten_years_ms()),
    KrV       = maps:get(k_realm_version, P, undefined),
    {ok, #issue_license_v1{
        license_id        = LId,
        file_id           = FId,
        grantee           = G,
        wrap_strategy     = WS,
        wrapped_cek       = WC,
        origin_cek_sealed = OCS,
        k_realm_version   = KrV,
        issuer_did        = Issuer,
        realm             = Realm,
        batch_id          = BId,
        issued_at         = IssuedAt,
        expires_at        = ExpiresAt}};
new(_) ->
    {error, missing_fields}.

-spec get_license_id(issue_license_v1()) -> binary().
get_license_id(#issue_license_v1{license_id = L}) -> L.

-spec to_map(issue_license_v1()) -> map().
to_map(#issue_license_v1{} = C) ->
    #{license_id        => C#issue_license_v1.license_id,
      file_id           => C#issue_license_v1.file_id,
      grantee           => C#issue_license_v1.grantee,
      wrap_strategy     => C#issue_license_v1.wrap_strategy,
      wrapped_cek       => C#issue_license_v1.wrapped_cek,
      origin_cek_sealed => C#issue_license_v1.origin_cek_sealed,
      k_realm_version   => C#issue_license_v1.k_realm_version,
      issuer_did        => C#issue_license_v1.issuer_did,
      realm             => C#issue_license_v1.realm,
      batch_id          => C#issue_license_v1.batch_id,
      issued_at         => C#issue_license_v1.issued_at,
      expires_at        => C#issue_license_v1.expires_at}.

-spec from_map(map()) -> {ok, issue_license_v1()} | {error, term()}.
from_map(Map) -> new(Map).

%% --- Internal ---

ten_years_ms() -> 10 * 365 * 24 * 3600 * 1000.
