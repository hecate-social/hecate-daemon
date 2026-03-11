%%% @doc Offering aggregate state record.

-record(offering_state, {
    offering_id        :: binary() | undefined,
    plugin_id          :: binary() | undefined,
    author_id          :: binary() | undefined,
    status             :: non_neg_integer(),
    %% Marketing fields
    plugin_name        :: binary() | undefined,
    display_name       :: binary() | undefined,
    description        :: binary() | undefined,
    icon               :: binary() | undefined,
    group_name         :: binary() | undefined,
    group_icon         :: binary() | undefined,
    github_repo        :: binary() | undefined,
    homepage           :: binary() | undefined,
    tags               :: binary() | undefined,
    %% Technical fields
    oci_image          :: binary() | undefined,
    package_url        :: binary() | undefined,
    plugin_type        :: binary() | undefined,
    callback_module    :: binary() | undefined,
    org                :: binary() | undefined,
    version            :: binary() | undefined,
    manifest_tag       :: binary() | undefined,
    min_daemon_version :: binary() | undefined,
    publisher_identity :: binary() | undefined,
    %% Commercial fields
    selling_formula    :: binary() | undefined,
    license_type       :: binary() | undefined,
    fee_cents          :: non_neg_integer() | undefined,
    fee_currency       :: binary() | undefined,
    duration_days      :: non_neg_integer() | undefined,
    node_limit         :: non_neg_integer() | undefined,
    %% Trust verification fields
    manifest_url       :: binary() | undefined,
    manifest_checksum  :: binary() | undefined,
    author_signature   :: binary() | undefined,
    oci_image_verified :: 0 | 1 | undefined,
    oci_image_digest   :: binary() | undefined,
    %% Timestamps
    initiated_at       :: integer() | undefined,
    announced_at       :: integer() | undefined,
    published_at       :: integer() | undefined,
    retracted_at       :: integer() | undefined,
    archived_at        :: integer() | undefined
}).
