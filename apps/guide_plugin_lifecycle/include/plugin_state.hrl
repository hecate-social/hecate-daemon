%%% @doc Plugin aggregate state record (node context).

-record(plugin_state, {
    plugin_id         :: binary() | undefined,
    name              :: binary() | undefined,
    plugin_type       :: binary() | undefined,       %% <<"container">> | <<"in_vm">>
    callback_module   :: binary() | undefined,       %% e.g., <<"app_scribe">> (in_vm only)
    oci_image         :: binary() | undefined,       %% (container only)
    package_url       :: binary() | undefined,       %% URL to .tar.gz (in_vm only)
    installed_version :: binary() | undefined,
    license_id        :: binary() | undefined,
    icon              :: binary() | undefined,
    group_name        :: binary() | undefined,
    group_icon        :: binary() | undefined,
    installed_at      :: integer() | undefined,
    upgraded_at       :: integer() | undefined,
    removed_at        :: integer() | undefined,
    started_at        :: integer() | undefined,
    stopped_at        :: integer() | undefined,
    extracted_at      :: integer() | undefined,      %% in_vm: when package was extracted
    status            :: non_neg_integer()
}).
