%%% @doc License aggregate state record.

-record(license_state, {
    license_id        :: binary() | undefined,
    user_id           :: binary() | undefined,
    plugin_id         :: binary() | undefined,
    status            :: non_neg_integer(),
    oci_image         :: binary() | undefined,
    granted_at        :: integer() | undefined,
    revoked_at        :: integer() | undefined,
    archived_at       :: integer() | undefined,
    %% Seller-side fields
    plugin_name       :: binary() | undefined,
    description       :: binary() | undefined,
    icon              :: binary() | undefined,
    github_repo       :: binary() | undefined,
    selling_formula   :: binary() | undefined,
    seller_id         :: binary() | undefined,
    org               :: binary() | undefined,
    version           :: binary() | undefined,
    manifest_tag      :: binary() | undefined,
    tags              :: binary() | undefined,
    homepage          :: binary() | undefined,
    min_daemon_version :: binary() | undefined,
    publisher_identity :: binary() | undefined,
    initiated_at      :: integer() | undefined,
    announced_at      :: integer() | undefined,
    published_at      :: integer() | undefined
}).
