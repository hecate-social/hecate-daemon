%%% @doc Recipient-side share-license aggregate state.
%%%
%%% One record per license the recipient accepted. Stream:
%%% `accepted-license-{license_id}`. The recipient's view of an
%%% issued-elsewhere license.

-record(accepted_license_state, {
    license_id          :: binary() | undefined,
    file_id             :: binary() | undefined,
    grantee             :: binary() | undefined,
    wrap_strategy       :: atom()   | undefined,
    wrapped_cek         :: binary() | undefined,         %% current wrapped form (updated on rewrap)
    accepted_cek_sealed :: binary() | undefined,         %% plaintext CEK sealed via hecate_crypto
    k_realm_version     :: non_neg_integer() | undefined,
    issuer_did          :: binary() | undefined,
    realm               :: binary() | undefined,
    issued_at           :: integer() | undefined,
    accepted_at         :: integer() | undefined,
    ended_at            :: integer() | undefined,
    end_reason          :: atom()   | undefined,
    expires_at          :: integer() | undefined,
    status              :: non_neg_integer()
}).
