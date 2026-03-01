%%% @doc Projection: license_retracted_v1 -> plugin_catalog table.
%%% Resets the catalog row to draft (retracted) state.
-module(license_retracted_v1_to_sqlite_catalog).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(EventMap) ->
    LicenseId = hecate_api_utils:get_field(license_id, EventMap),

    Sql = "UPDATE plugin_catalog SET status = 1, retracted = 1, "
          "status_label = 'Retracted', announced_at = NULL, published_at = NULL "
          "WHERE license_id = ?1",
    project_licenses_store:execute(Sql, [LicenseId]).
