%%% @doc Projection: plugin_installed_v1 -> plugins table (INSERT OR REPLACE).
-module(plugin_installed_v1_to_sqlite_plugins).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    PluginId  = hecate_api_utils:get_field(plugin_id, Event),
    Name      = hecate_api_utils:get_field(name, Event),
    OciImage  = hecate_api_utils:get_field(oci_image, Event),
    Version   = hecate_api_utils:get_field(installed_version, Event),
    LicenseId = hecate_api_utils:get_field(license_id, Event),
    InstalledAt = hecate_api_utils:get_field(installed_at, Event),
    Sql = "INSERT OR REPLACE INTO plugins "
          "(plugin_id, name, oci_image, installed_version, license_id, "
          "installed_at, upgraded_at, removed_at, status, status_label) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, NULL, NULL, 1, 'Installed')",
    project_plugins_store:execute(Sql, [PluginId, Name, OciImage, Version, LicenseId, InstalledAt]).
