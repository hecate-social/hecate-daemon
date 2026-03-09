%%% @doc initiate_license_v1 command
%%% Full birth event for a consumer license with offering snapshot.
%%% The user clicked "Get" on a known offering — all data is available.
%%% Required: consumer_id, plugin_id, offering_id.
%%% Offering fields are deep-copied as a point-in-time snapshot.
-module(initiate_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_consumer_id/1, get_plugin_id/1, get_offering_id/1,
         get_plugin_name/1, get_description/1, get_icon/1, get_group_name/1,
         get_github_repo/1, get_oci_image/1, get_selling_formula/1, get_author_id/1,
         get_license_type/1, get_fee_cents/1, get_fee_currency/1, get_duration_days/1,
         get_node_limit/1, get_org/1, get_version/1, get_manifest_tag/1, get_tags/1,
         get_homepage/1, get_min_daemon_version/1, get_publisher_identity/1,
         get_manifest_url/1, get_manifest_checksum/1, get_author_signature/1,
         get_oci_image_verified/1, get_oci_image_digest/1]).

-record(initiate_license_v1, {
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
    oci_image_digest   :: binary() | undefined
}).

-export_type([initiate_license_v1/0]).
-opaque initiate_license_v1() :: #initiate_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_license_v1()} | {error, term()}.
new(#{consumer_id := ConsumerId, plugin_id := PluginId, offering_id := OfferingId} = P) ->
    LicenseId = <<"license-", ConsumerId/binary, "-", PluginId/binary>>,
    {ok, #initiate_license_v1{
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
        oci_image_digest   = maps:get(oci_image_digest, P, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_license_v1()) -> {ok, initiate_license_v1()} | {error, term()}.
validate(#initiate_license_v1{consumer_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_consumer_id};
validate(#initiate_license_v1{plugin_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_plugin_id};
validate(#initiate_license_v1{offering_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_offering_id};
validate(#initiate_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_license_v1()) -> map().
to_map(#initiate_license_v1{} = C) ->
    #{
        <<"command_type">>      => <<"initiate_license">>,
        <<"license_id">>        => C#initiate_license_v1.license_id,
        <<"consumer_id">>       => C#initiate_license_v1.consumer_id,
        <<"plugin_id">>         => C#initiate_license_v1.plugin_id,
        <<"offering_id">>       => C#initiate_license_v1.offering_id,
        <<"plugin_name">>       => C#initiate_license_v1.plugin_name,
        <<"description">>       => C#initiate_license_v1.description,
        <<"icon">>              => C#initiate_license_v1.icon,
        <<"group_name">>        => C#initiate_license_v1.group_name,
        <<"github_repo">>       => C#initiate_license_v1.github_repo,
        <<"oci_image">>         => C#initiate_license_v1.oci_image,
        <<"selling_formula">>   => C#initiate_license_v1.selling_formula,
        <<"author_id">>         => C#initiate_license_v1.author_id,
        <<"license_type">>      => C#initiate_license_v1.license_type,
        <<"fee_cents">>         => C#initiate_license_v1.fee_cents,
        <<"fee_currency">>      => C#initiate_license_v1.fee_currency,
        <<"duration_days">>     => C#initiate_license_v1.duration_days,
        <<"node_limit">>        => C#initiate_license_v1.node_limit,
        <<"org">>               => C#initiate_license_v1.org,
        <<"version">>           => C#initiate_license_v1.version,
        <<"manifest_tag">>      => C#initiate_license_v1.manifest_tag,
        <<"tags">>              => C#initiate_license_v1.tags,
        <<"homepage">>          => C#initiate_license_v1.homepage,
        <<"min_daemon_version">> => C#initiate_license_v1.min_daemon_version,
        <<"publisher_identity">> => C#initiate_license_v1.publisher_identity,
        <<"manifest_url">>      => C#initiate_license_v1.manifest_url,
        <<"manifest_checksum">> => C#initiate_license_v1.manifest_checksum,
        <<"author_signature">>  => C#initiate_license_v1.author_signature,
        <<"oci_image_verified">> => C#initiate_license_v1.oci_image_verified,
        <<"oci_image_digest">>  => C#initiate_license_v1.oci_image_digest
    }.

-spec from_map(map()) -> {ok, initiate_license_v1()} | {error, term()}.
from_map(Map) ->
    ConsumerId = hecate_api_utils:get_field(consumer_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case {ConsumerId, PluginId, OfferingId} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            LicenseId = <<"license-", ConsumerId/binary, "-", PluginId/binary>>,
            {ok, #initiate_license_v1{
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
                oci_image_digest   = hecate_api_utils:get_field(oci_image_digest, Map, undefined)
            }}
    end.

%% Accessors
-spec get_license_id(initiate_license_v1()) -> binary().
get_license_id(#initiate_license_v1{license_id = V}) -> V.

-spec get_consumer_id(initiate_license_v1()) -> binary().
get_consumer_id(#initiate_license_v1{consumer_id = V}) -> V.

-spec get_plugin_id(initiate_license_v1()) -> binary().
get_plugin_id(#initiate_license_v1{plugin_id = V}) -> V.

-spec get_offering_id(initiate_license_v1()) -> binary().
get_offering_id(#initiate_license_v1{offering_id = V}) -> V.

-spec get_plugin_name(initiate_license_v1()) -> binary() | undefined.
get_plugin_name(#initiate_license_v1{plugin_name = V}) -> V.

-spec get_description(initiate_license_v1()) -> binary() | undefined.
get_description(#initiate_license_v1{description = V}) -> V.

-spec get_icon(initiate_license_v1()) -> binary() | undefined.
get_icon(#initiate_license_v1{icon = V}) -> V.

-spec get_group_name(initiate_license_v1()) -> binary() | undefined.
get_group_name(#initiate_license_v1{group_name = V}) -> V.

-spec get_github_repo(initiate_license_v1()) -> binary() | undefined.
get_github_repo(#initiate_license_v1{github_repo = V}) -> V.

-spec get_oci_image(initiate_license_v1()) -> binary() | undefined.
get_oci_image(#initiate_license_v1{oci_image = V}) -> V.

-spec get_selling_formula(initiate_license_v1()) -> binary() | undefined.
get_selling_formula(#initiate_license_v1{selling_formula = V}) -> V.

-spec get_author_id(initiate_license_v1()) -> binary() | undefined.
get_author_id(#initiate_license_v1{author_id = V}) -> V.

-spec get_license_type(initiate_license_v1()) -> binary() | undefined.
get_license_type(#initiate_license_v1{license_type = V}) -> V.

-spec get_fee_cents(initiate_license_v1()) -> non_neg_integer() | undefined.
get_fee_cents(#initiate_license_v1{fee_cents = V}) -> V.

-spec get_fee_currency(initiate_license_v1()) -> binary() | undefined.
get_fee_currency(#initiate_license_v1{fee_currency = V}) -> V.

-spec get_duration_days(initiate_license_v1()) -> non_neg_integer() | undefined.
get_duration_days(#initiate_license_v1{duration_days = V}) -> V.

-spec get_node_limit(initiate_license_v1()) -> non_neg_integer() | undefined.
get_node_limit(#initiate_license_v1{node_limit = V}) -> V.

-spec get_org(initiate_license_v1()) -> binary() | undefined.
get_org(#initiate_license_v1{org = V}) -> V.

-spec get_version(initiate_license_v1()) -> binary() | undefined.
get_version(#initiate_license_v1{version = V}) -> V.

-spec get_manifest_tag(initiate_license_v1()) -> binary() | undefined.
get_manifest_tag(#initiate_license_v1{manifest_tag = V}) -> V.

-spec get_tags(initiate_license_v1()) -> binary() | undefined.
get_tags(#initiate_license_v1{tags = V}) -> V.

-spec get_homepage(initiate_license_v1()) -> binary() | undefined.
get_homepage(#initiate_license_v1{homepage = V}) -> V.

-spec get_min_daemon_version(initiate_license_v1()) -> binary() | undefined.
get_min_daemon_version(#initiate_license_v1{min_daemon_version = V}) -> V.

-spec get_publisher_identity(initiate_license_v1()) -> binary() | undefined.
get_publisher_identity(#initiate_license_v1{publisher_identity = V}) -> V.

-spec get_manifest_url(initiate_license_v1()) -> binary() | undefined.
get_manifest_url(#initiate_license_v1{manifest_url = V}) -> V.

-spec get_manifest_checksum(initiate_license_v1()) -> binary() | undefined.
get_manifest_checksum(#initiate_license_v1{manifest_checksum = V}) -> V.

-spec get_author_signature(initiate_license_v1()) -> binary() | undefined.
get_author_signature(#initiate_license_v1{author_signature = V}) -> V.

-spec get_oci_image_verified(initiate_license_v1()) -> 0 | 1 | undefined.
get_oci_image_verified(#initiate_license_v1{oci_image_verified = V}) -> V.

-spec get_oci_image_digest(initiate_license_v1()) -> binary() | undefined.
get_oci_image_digest(#initiate_license_v1{oci_image_digest = V}) -> V.
