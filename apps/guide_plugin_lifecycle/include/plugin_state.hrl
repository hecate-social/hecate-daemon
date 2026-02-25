%%% @doc Plugin aggregate state record (node context).

-record(plugin_state, {
    plugin_id         :: binary() | undefined,
    name              :: binary() | undefined,
    oci_image         :: binary() | undefined,
    installed_version :: binary() | undefined,
    license_id        :: binary() | undefined,
    installed_at      :: integer() | undefined,
    upgraded_at       :: integer() | undefined,
    removed_at        :: integer() | undefined,
    status            :: non_neg_integer()
}).
