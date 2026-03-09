%%% @doc Consumer license aggregate state record.
%%%
%%% Deep-copies offering data at initiation time (the user clicked "Get"
%%% on a known offering), making the license a self-contained dossier
%%% independent of the offering aggregate.

-record(license_state, {
    license_id         :: binary() | undefined,
    consumer_id        :: binary() | undefined,
    offering_id        :: binary() | undefined,
    plugin_id          :: binary() | undefined,
    status             :: non_neg_integer(),
    %% Deep-copied offering fields (snapshot at acceptance)
    plugin_name        :: binary() | undefined,
    description        :: binary() | undefined,
    icon               :: binary() | undefined,
    group_name         :: binary() | undefined,
    github_repo        :: binary() | undefined,
    oci_image          :: binary() | undefined,
    selling_formula    :: binary() | undefined,
    author_id          :: binary() | undefined,
    license_type       :: binary() | undefined,
    fee_cents          :: non_neg_integer() | undefined,
    fee_currency       :: binary() | undefined,
    duration_days      :: non_neg_integer() | undefined,
    node_limit         :: non_neg_integer() | undefined,
    org                :: binary() | undefined,
    version            :: binary() | undefined,
    manifest_tag       :: binary() | undefined,
    tags               :: binary() | undefined,
    homepage           :: binary() | undefined,
    min_daemon_version :: binary() | undefined,
    publisher_identity :: binary() | undefined,
    manifest_url       :: binary() | undefined,
    manifest_checksum  :: binary() | undefined,
    author_signature   :: binary() | undefined,
    oci_image_verified :: 0 | 1 | undefined,
    oci_image_digest   :: binary() | undefined,
    %% Lifecycle timestamps
    initiated_at       :: integer() | undefined,
    accepted_at        :: integer() | undefined,
    rejected_at        :: integer() | undefined,
    bought_at          :: integer() | undefined,
    abandoned_at       :: integer() | undefined,
    granted_at         :: integer() | undefined,
    expired_at         :: integer() | undefined,
    renewed_at         :: integer() | undefined,
    revoked_at         :: integer() | undefined,
    archived_at        :: integer() | undefined
}).
