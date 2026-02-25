%%% @doc Projection: license_revoked_v1 -> licenses table (UPDATE revoked).
-module(license_revoked_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId = hecate_api_utils:get_field(license_id, Event),
    RevokedAt = hecate_api_utils:get_field(revoked_at, Event),
    Sql = "UPDATE licenses SET revoked_at = ?2, revoked = 1, "
          "status = status | 16, status_label = 'Revoked' WHERE license_id = ?1",
    project_licenses_store:execute(Sql, [LicenseId, RevokedAt]).
