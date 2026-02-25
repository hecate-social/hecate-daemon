%%% @doc Projection: license_archived_v1 -> licenses table (UPDATE archived).
-module(license_archived_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId  = hecate_api_utils:get_field(license_id, Event),
    ArchivedAt = hecate_api_utils:get_field(archived_at, Event),
    Sql = "UPDATE licenses SET archived_at = ?2, "
          "status = status | 32, status_label = 'Archived' WHERE license_id = ?1",
    project_licenses_store:execute(Sql, [LicenseId, ArchivedAt]).
