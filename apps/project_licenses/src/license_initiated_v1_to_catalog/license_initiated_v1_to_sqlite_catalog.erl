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
    CatalogedAt = hecate_api_utils:get_field(initiated_at, EventMap),

    Sql = "INSERT OR REPLACE INTO plugin_catalog "
          "(plugin_id, license_id, name, description, icon, github_repo, "
          "oci_image, selling_formula, seller_id, "
          "org, version, manifest_tag, tags, homepage, "
          "min_daemon_version, publisher_identity, cataloged_at, "
          "refreshed_at, retracted, status, status_label) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, "
          "?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, NULL, 0, ?18, ?19)",
    Params = [PluginId, LicenseId, Name, Description, Icon, GithubRepo,
              OciImage, SellingFormula, SellerId,
              Org, Version, ManifestTag, Tags, Homepage,
              MinDaemonVersion, PublisherIdentity, CatalogedAt,
              1, <<"Initiated">>],
    project_licenses_store:execute(Sql, Params).
