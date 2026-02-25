%%% @doc Projection: plugin_upgraded_v1 -> plugins table (UPDATE).
-module(plugin_upgraded_v1_to_sqlite_plugins).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    PluginId   = hecate_api_utils:get_field(plugin_id, Event),
    OciImage   = hecate_api_utils:get_field(oci_image, Event),
    Version    = hecate_api_utils:get_field(installed_version, Event),
    UpgradedAt = hecate_api_utils:get_field(upgraded_at, Event),
    Sql = "UPDATE plugins SET "
          "oci_image = ?1, installed_version = ?2, upgraded_at = ?3 "
          "WHERE plugin_id = ?4",
    project_plugins_store:execute(Sql, [OciImage, Version, UpgradedAt, PluginId]).
