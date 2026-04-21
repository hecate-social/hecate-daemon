%%% @doc Realm membership aggregate state record.

-record(membership_state, {
    membership_id         :: binary() | undefined,
    realm_id              :: binary() | undefined,
    realm_url             :: binary() | undefined,
    oauth_account         :: binary() | undefined,
    oauth_provider        :: binary() | undefined,
    encrypted_credentials :: binary() | undefined,
    initiated_at          :: integer() | undefined,
    confirmed_at          :: integer() | undefined,
    revoked_at            :: integer() | undefined,
    secured_at            :: integer() | undefined,
    %% K_realm — realm-wide shared symmetric key fetched from the realm
    %% server on confirm and re-sealed daemon-locally via hecate_crypto.
    k_realm_version       :: non_neg_integer() | undefined,
    k_realm_encrypted     :: binary() | undefined,
    k_realm_received_at   :: integer() | undefined,
    %% X25519 encryption pubkey announced to the realm directory.
    identity_pubkey_announced_at :: integer() | undefined,
    status                :: non_neg_integer()
}).
