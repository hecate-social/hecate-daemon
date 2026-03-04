%%% @doc API handler: GET /api/appstore/catalog/:id
%%%
%%% Returns details for a single catalog entry, including license
%%% and install status for the current user.
%%% @end
-module(get_catalog_entry_api).

-export([init/2, routes/0]).

-ifdef(TEST).
-compile(export_all).
-compile(nowarn_export_all).
-endif.

-define(CATALOG_COLUMNS, [
    plugin_id, license_id, name, org, version, description, icon,
    github_repo, oci_image, manifest_tag, tags, homepage,
    min_daemon_version, publisher_identity, selling_formula, seller_id,
    license_type, fee_cents, fee_currency, duration_days, node_limit,
    announced_at, published_at, cataloged_at, refreshed_at,
    status, status_label, retracted
]).

-define(LICENSE_COLUMNS, [
    license_id, user_id, plugin_id, plugin_name,
    installed, installed_version, oci_image,
    granted_at, installed_at, upgraded_at, revoked, revoked_at
]).

-define(CATALOG_SQL,
    "SELECT plugin_id, license_id, name, org, version, description, icon, "
    "github_repo, oci_image, manifest_tag, tags, homepage, "
    "min_daemon_version, publisher_identity, selling_formula, seller_id, "
    "license_type, fee_cents, fee_currency, duration_days, node_limit, "
    "announced_at, published_at, cataloged_at, refreshed_at, "
    "status, status_label, retracted "
    "FROM plugin_catalog WHERE plugin_id = ?1").

-define(LICENSE_SQL,
    "SELECT license_id, user_id, plugin_id, plugin_name, "
    "installed, installed_version, oci_image, "
    "granted_at, installed_at, upgraded_at, revoked, revoked_at "
    "FROM licenses WHERE plugin_id = ?1 AND user_id = ?2 AND (status & 32) = 0").

routes() -> [{"/api/appstore/catalog/:id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            hecate_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        UserId ->
            PluginId = cowboy_req:binding(id, Req0),
            case project_licenses_store:query(?CATALOG_SQL, [PluginId]) of
                {ok, [Row]} ->
                    Plugin = row_to_map(?CATALOG_COLUMNS, Row),
                    License = fetch_license(PluginId, UserId),
                    Result = Plugin#{license => License},
                    hecate_api_utils:json_ok(#{plugin => Result}, Req0);
                {ok, []} ->
                    hecate_api_utils:not_found(Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.

fetch_license(PluginId, UserId) ->
    case project_licenses_store:query(?LICENSE_SQL, [PluginId, UserId]) of
        {ok, [Row]} -> row_to_map(?LICENSE_COLUMNS, Row);
        {ok, []} -> null;
        {error, _} -> null
    end.

row_to_map(Columns, Row) when is_list(Row) ->
    maps:from_list(lists:zip(Columns, Row));
row_to_map(Columns, Row) when is_tuple(Row) ->
    maps:from_list(lists:zip(Columns, tuple_to_list(Row))).
