%%% @doc license_initiated_v1 event
%%% Emitted when a consumer starts the license process.
%%% Carries the full offering snapshot — the aggregate is fully
%%% populated at birth since the offering is known at click time.
-module(license_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_consumer_id/1, get_plugin_id/1,
         get_offering_id/1, get_initiated_at/1]).

-record(license_initiated_v1, {
    license_id         :: binary(),
    consumer_id        :: binary(),
    plugin_id          :: binary(),
    offering_id        :: binary(),
    %% Deep-copied offering fields
    plugin_name        :: binary() | undefined,
    description        :: binary() | undefined,
    icon               :: binary() | undefined,
    group_name         :: binary() | undefined,
    github_repo        :: binary() | undefined,
    oci_image          :: binary() | undefined,
    selling_formula    :: binary() | undefined,
    author_id          :: binary() | undefined,
    license_type       :: binary() | undefined,
    fee_cents          :: non_neg_integer() | undefined,
    fee_currency       :: binary() | undefined,
    duration_days      :: non_neg_integer() | undefined,
    node_limit         :: non_neg_integer() | undefined,
    org                :: binary() | undefined,
    version            :: binary() | undefined,
    manifest_tag       :: binary() | undefined,
    tags               :: binary() | undefined,
    homepage           :: binary() | undefined,
    min_daemon_version :: binary() | undefined,
    publisher_identity :: binary() | undefined,
    manifest_url       :: binary() | undefined,
    manifest_checksum  :: binary() | undefined,
    author_signature   :: binary() | undefined,
    oci_image_verified :: 0 | 1 | undefined,
    oci_image_digest   :: binary() | undefined,
    initiated_at       :: integer()
}).

-export_type([license_initiated_v1/0]).
-opaque license_initiated_v1() :: #license_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_initiated_v1().
new(#{license_id := LicenseId, consumer_id := ConsumerId,
      plugin_id := PluginId, offering_id := OfferingId} = P) ->
    #license_initiated_v1{
        license_id         = LicenseId,
        consumer_id        = ConsumerId,
        plugin_id          = PluginId,
        offering_id        = OfferingId,
        plugin_name        = maps:get(plugin_name, P, undefined),
        description        = maps:get(description, P, undefined),
        icon               = maps:get(icon, P, undefined),
        group_name         = maps:get(group_name, P, undefined),
        github_repo        = maps:get(github_repo, P, undefined),
        oci_image          = maps:get(oci_image, P, undefined),
        selling_formula    = maps:get(selling_formula, P, undefined),
        author_id          = maps:get(author_id, P, undefined),
        license_type       = maps:get(license_type, P, undefined),
        fee_cents          = maps:get(fee_cents, P, undefined),
        fee_currency       = maps:get(fee_currency, P, undefined),
        duration_days      = maps:get(duration_days, P, undefined),
        node_limit         = maps:get(node_limit, P, undefined),
        org                = maps:get(org, P, undefined),
        version            = maps:get(version, P, undefined),
        manifest_tag       = maps:get(manifest_tag, P, undefined),
        tags               = maps:get(tags, P, undefined),
        homepage           = maps:get(homepage, P, undefined),
        min_daemon_version = maps:get(min_daemon_version, P, undefined),
        publisher_identity = maps:get(publisher_identity, P, undefined),
        manifest_url       = maps:get(manifest_url, P, undefined),
        manifest_checksum  = maps:get(manifest_checksum, P, undefined),
        author_signature   = maps:get(author_signature, P, undefined),
        oci_image_verified = maps:get(oci_image_verified, P, undefined),
        oci_image_digest   = maps:get(oci_image_digest, P, undefined),
        initiated_at       = erlang:system_time(millisecond)
    }.

-spec to_map(license_initiated_v1()) -> map().
to_map(#license_initiated_v1{} = E) ->
    #{
        event_type          => <<"license_initiated_v1">>,
        license_id          => E#license_initiated_v1.license_id,
        consumer_id         => E#license_initiated_v1.consumer_id,
        plugin_id           => E#license_initiated_v1.plugin_id,
        offering_id         => E#license_initiated_v1.offering_id,
        plugin_name         => E#license_initiated_v1.plugin_name,
        description         => E#license_initiated_v1.description,
        icon                => E#license_initiated_v1.icon,
        group_name          => E#license_initiated_v1.group_name,
        github_repo         => E#license_initiated_v1.github_repo,
        oci_image           => E#license_initiated_v1.oci_image,
        selling_formula     => E#license_initiated_v1.selling_formula,
        author_id           => E#license_initiated_v1.author_id,
        license_type        => E#license_initiated_v1.license_type,
        fee_cents           => E#license_initiated_v1.fee_cents,
        fee_currency        => E#license_initiated_v1.fee_currency,
        duration_days       => E#license_initiated_v1.duration_days,
        node_limit          => E#license_initiated_v1.node_limit,
        org                 => E#license_initiated_v1.org,
        version             => E#license_initiated_v1.version,
        manifest_tag        => E#license_initiated_v1.manifest_tag,
        tags                => E#license_initiated_v1.tags,
        homepage            => E#license_initiated_v1.homepage,
        min_daemon_version  => E#license_initiated_v1.min_daemon_version,
        publisher_identity  => E#license_initiated_v1.publisher_identity,
        manifest_url        => E#license_initiated_v1.manifest_url,
        manifest_checksum   => E#license_initiated_v1.manifest_checksum,
        author_signature    => E#license_initiated_v1.author_signature,
        oci_image_verified  => E#license_initiated_v1.oci_image_verified,
        oci_image_digest    => E#license_initiated_v1.oci_image_digest,
        initiated_at        => E#license_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, license_initiated_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    ConsumerId = hecate_api_utils:get_field(consumer_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case {LicenseId, ConsumerId, PluginId, OfferingId} of
        {undefined, _, _, _} -> {error, invalid_event};
        {_, undefined, _, _} -> {error, invalid_event};
        {_, _, undefined, _} -> {error, invalid_event};
        {_, _, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #license_initiated_v1{
                license_id         = LicenseId,
                consumer_id        = ConsumerId,
                plugin_id          = PluginId,
                offering_id        = OfferingId,
                plugin_name        = hecate_api_utils:get_field(plugin_name, Map, undefined),
                description        = hecate_api_utils:get_field(description, Map, undefined),
                icon               = hecate_api_utils:get_field(icon, Map, undefined),
                group_name         = hecate_api_utils:get_field(group_name, Map, undefined),
                github_repo        = hecate_api_utils:get_field(github_repo, Map, undefined),
                oci_image          = hecate_api_utils:get_field(oci_image, Map, undefined),
                selling_formula    = hecate_api_utils:get_field(selling_formula, Map, undefined),
                author_id          = hecate_api_utils:get_field(author_id, Map, undefined),
                license_type       = hecate_api_utils:get_field(license_type, Map, undefined),
                fee_cents          = hecate_api_utils:get_field(fee_cents, Map, undefined),
                fee_currency       = hecate_api_utils:get_field(fee_currency, Map, undefined),
                duration_days      = hecate_api_utils:get_field(duration_days, Map, undefined),
                node_limit         = hecate_api_utils:get_field(node_limit, Map, undefined),
                org                = hecate_api_utils:get_field(org, Map, undefined),
                version            = hecate_api_utils:get_field(version, Map, undefined),
                manifest_tag       = hecate_api_utils:get_field(manifest_tag, Map, undefined),
                tags               = hecate_api_utils:get_field(tags, Map, undefined),
                homepage           = hecate_api_utils:get_field(homepage, Map, undefined),
                min_daemon_version = hecate_api_utils:get_field(min_daemon_version, Map, undefined),
                publisher_identity = hecate_api_utils:get_field(publisher_identity, Map, undefined),
                manifest_url       = hecate_api_utils:get_field(manifest_url, Map, undefined),
                manifest_checksum  = hecate_api_utils:get_field(manifest_checksum, Map, undefined),
                author_signature   = hecate_api_utils:get_field(author_signature, Map, undefined),
                oci_image_verified = hecate_api_utils:get_field(oci_image_verified, Map, undefined),
                oci_image_digest   = hecate_api_utils:get_field(oci_image_digest, Map, undefined),
                initiated_at       = hecate_api_utils:get_field(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(license_initiated_v1()) -> binary().
get_license_id(#license_initiated_v1{license_id = V}) -> V.

-spec get_consumer_id(license_initiated_v1()) -> binary().
get_consumer_id(#license_initiated_v1{consumer_id = V}) -> V.

-spec get_plugin_id(license_initiated_v1()) -> binary().
get_plugin_id(#license_initiated_v1{plugin_id = V}) -> V.

-spec get_offering_id(license_initiated_v1()) -> binary().
get_offering_id(#license_initiated_v1{offering_id = V}) -> V.

-spec get_initiated_at(license_initiated_v1()) -> integer().
get_initiated_at(#license_initiated_v1{initiated_at = V}) -> V.
