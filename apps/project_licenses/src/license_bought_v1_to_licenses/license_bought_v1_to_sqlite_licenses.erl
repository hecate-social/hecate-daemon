%%% @doc Projection: license_bought_v1 -> licenses table (INSERT).
-module(license_bought_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId  = hecate_api_utils:get_field(license_id, Event),
    UserId     = hecate_api_utils:get_field(user_id, Event),
    PluginId   = hecate_api_utils:get_field(plugin_id, Event),
    PluginName = hecate_api_utils:get_field(plugin_name, Event),
    OciImage   = hecate_api_utils:get_field(oci_image, Event),
    GrantedAt  = hecate_api_utils:get_field(granted_at, Event),
    Sql = "INSERT INTO licenses "
          "(license_id, user_id, plugin_id, plugin_name, oci_image, granted_at, "
          "installed, installed_version, installed_at, upgraded_at, revoked, "
          "status, status_label) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, 0, NULL, NULL, NULL, 0, 8, 'Licensed')",
    project_licenses_store:execute(Sql, [LicenseId, UserId, PluginId, PluginName, OciImage, GrantedAt]).
