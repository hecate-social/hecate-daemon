%%% @doc Projection: license_initiated_v1 -> plugin_catalog table.
%%% Inserts a new row in the catalog when a seller initiates a license.
-module(license_initiated_v1_to_sqlite_catalog).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(EventMap) ->
    LicenseId = hecate_api_utils:get_field(license_id, EventMap),
    PluginId = hecate_api_utils:get_field(plugin_id, EventMap),
    Name = hecate_api_utils:get_field(plugin_name, EventMap),
    Description = hecate_api_utils:get_field(description, EventMap),
    Icon = hecate_api_utils:get_field(icon, EventMap),
    GithubRepo = hecate_api_utils:get_field(github_repo, EventMap),
    OciImage = hecate_api_utils:get_field(oci_image, EventMap),
    SellingFormula = hecate_api_utils:get_field(selling_formula, EventMap),
    SellerId = hecate_api_utils:get_field(seller_id, EventMap),
    Org = hecate_api_utils:get_field(org, EventMap),
    Version = hecate_api_utils:get_field(version, EventMap),
    ManifestTag = hecate_api_utils:get_field(manifest_tag, EventMap),
    Tags = hecate_api_utils:get_field(tags, EventMap),
    Homepage = hecate_api_utils:get_field(homepage, EventMap),
    MinDaemonVersion = hecate_api_utils:get_field(min_daemon_version, EventMap),
    PublisherIdentity = hecate_api_utils:get_field(publisher_identity, EventMap),
    LicenseType = hecate_api_utils:get_field(license_type, EventMap),
    FeeCents = hecate_api_utils:get_field(fee_cents, EventMap),
    FeeCurrency = hecate_api_utils:get_field(fee_currency, EventMap),
    DurationDays = hecate_api_utils:get_field(duration_days, EventMap),
    NodeLimit = hecate_api_utils:get_field(node_limit, EventMap),
    ManifestUrl = hecate_api_utils:get_field(manifest_url, EventMap),
    ManifestChecksum = hecate_api_utils:get_field(manifest_checksum, EventMap),
    SellerSignature = hecate_api_utils:get_field(seller_signature, EventMap),
    OciImageVerified = hecate_api_utils:get_field(oci_image_verified, EventMap),
    OciImageDigest = hecate_api_utils:get_field(oci_image_digest, EventMap),
    CatalogedAt = hecate_api_utils:get_field(initiated_at, EventMap),

    Sql = "INSERT OR REPLACE INTO plugin_catalog "
          "(plugin_id, license_id, name, description, icon, github_repo, "
          "oci_image, selling_formula, seller_id, "
          "license_type, fee_cents, fee_currency, duration_days, node_limit, "
          "org, version, manifest_tag, tags, homepage, "
          "min_daemon_version, publisher_identity, "
          "manifest_url, manifest_checksum, seller_signature, "
          "oci_image_verified, oci_image_digest, "
          "cataloged_at, refreshed_at, retracted, status, status_label) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, "
          "?10, ?11, ?12, ?13, ?14, "
          "?15, ?16, ?17, ?18, ?19, "
          "?20, ?21, "
          "?22, ?23, ?24, ?25, ?26, "
          "?27, NULL, 0, ?28, ?29)",
    Params = [PluginId, LicenseId, Name, Description, Icon, GithubRepo,
              OciImage, SellingFormula, SellerId,
              LicenseType, FeeCents, FeeCurrency, DurationDays, NodeLimit,
              Org, Version, ManifestTag, Tags, Homepage,
              MinDaemonVersion, PublisherIdentity,
              ManifestUrl, ManifestChecksum, SellerSignature,
              OciImageVerified, OciImageDigest,
              CatalogedAt,
              1, <<"Initiated">>],
    project_licenses_store:execute(Sql, Params).
