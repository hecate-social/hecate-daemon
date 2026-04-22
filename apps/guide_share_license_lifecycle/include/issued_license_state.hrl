%%% @doc Issuer-side share-license aggregate state.
%%%
%%% One record per (file_id, grantee) the issuer minted. Stream:
%%% `issued-license-{license_id}`.

-record(issued_license_state, {
    license_id        :: binary() | undefined,
    file_id           :: binary() | undefined,
    grantee           :: binary() | undefined,         %% "mri:realm:..." or "did:macula:..."
    wrap_strategy     :: atom()   | undefined,         %% realm_key_v1 | did_x25519_v1
    wrapped_cek       :: binary() | undefined,
    origin_cek_sealed :: binary() | undefined,         %% plaintext CEK sealed via hecate_crypto (for rewrap)
    k_realm_version   :: non_neg_integer() | undefined,
    issuer_did        :: binary() | undefined,
    realm             :: binary() | undefined,
    batch_id          :: binary() | undefined,
    issued_at         :: integer() | undefined,
    expires_at        :: integer() | undefined,
    revoked_at        :: integer() | undefined,
    revoke_reason     :: atom()   | undefined,
    rewrapped_at      :: integer() | undefined,
    status            :: non_neg_integer()
}).
