%%% @doc API handler: GET /api/appstore/catalog
%%%
%%% Returns the full plugin catalog with license/install status
%%% for the current user. Only shows published plugins.
%%% @end
-module(browse_catalog_api).

-export([init/2, routes/0]).

-define(CATALOG_COLUMNS, [
    plugin_id, name, org, version, description, icon,
    oci_image, manifest_tag, tags, homepage, min_daemon_version,
    publisher_identity, selling_formula,
    license_type, fee_cents, fee_currency, duration_days, node_limit,
    published_at, cataloged_at, refreshed_at,
    status, retracted,
    license_id, installed, installed_version
]).

-define(SQL, "SELECT "
    "c.plugin_id, c.name, c.org, c.version, c.description, c.icon, "
    "c.oci_image, c.manifest_tag, c.tags, c.homepage, c.min_daemon_version, "
    "c.publisher_identity, c.selling_formula, "
    "c.license_type, c.fee_cents, c.fee_currency, c.duration_days, c.node_limit, "
    "c.published_at, c.cataloged_at, c.refreshed_at, "
    "c.status, c.retracted, "
    "l.license_id, l.installed, l.installed_version "
    "FROM plugin_catalog c "
    "LEFT JOIN licenses l ON c.plugin_id = l.plugin_id AND l.user_id = ?1 "
    "WHERE (c.status & 4) != 0 "
    "ORDER BY c.name").

routes() -> [{"/api/appstore/catalog", ?MODULE, []}].

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
            case project_licenses_store:query(?SQL, [UserId]) of
                {ok, Rows} ->
                    Items = [row_to_map(R) || R <- Rows],
                    hecate_api_utils:json_ok(#{items => Items}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.

row_to_map(Row) when is_list(Row) ->
    maps:from_list(lists:zip(?CATALOG_COLUMNS, Row));
row_to_map(Row) when is_tuple(Row) ->
    maps:from_list(lists:zip(?CATALOG_COLUMNS, tuple_to_list(Row))).
