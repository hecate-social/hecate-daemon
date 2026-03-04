%%% @doc API handler: GET /api/appstore/seller/listings
%%%
%%% Returns all plugin catalog entries for the authenticated seller,
%%% regardless of status (draft, announced, published).
%%% @end
-module(get_seller_listings_api).

-export([init/2, routes/0]).

-define(COLUMNS, [
    plugin_id, name, org, version, description, icon,
    oci_image, manifest_tag, tags, homepage, min_daemon_version,
    publisher_identity, selling_formula,
    license_type, fee_cents, fee_currency, duration_days, node_limit,
    manifest_url, manifest_checksum, seller_signature,
    oci_image_verified, oci_image_digest,
    published_at, cataloged_at, refreshed_at,
    status, retracted,
    seller_id, github_repo, announced_at, status_label
]).

-define(SQL, "SELECT "
    "c.plugin_id, c.name, c.org, c.version, c.description, c.icon, "
    "c.oci_image, c.manifest_tag, c.tags, c.homepage, c.min_daemon_version, "
    "c.publisher_identity, c.selling_formula, "
    "c.license_type, c.fee_cents, c.fee_currency, c.duration_days, c.node_limit, "
    "c.manifest_url, c.manifest_checksum, c.seller_signature, "
    "c.oci_image_verified, c.oci_image_digest, "
    "c.published_at, c.cataloged_at, c.refreshed_at, "
    "c.status, c.retracted, "
    "c.seller_id, c.github_repo, c.announced_at, c.status_label "
    "FROM plugin_catalog c "
    "WHERE c.seller_id = ?1 "
    "ORDER BY c.cataloged_at DESC").

routes() -> [{"/api/appstore/seller/listings", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            hecate_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        SellerId ->
            case project_licenses_store:query(?SQL, [SellerId]) of
                {ok, Rows} ->
                    Items = [row_to_map(R) || R <- Rows],
                    hecate_api_utils:json_ok(#{items => Items}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.

row_to_map(Row) when is_list(Row) ->
    maps:from_list(lists:zip(?COLUMNS, Row)).
