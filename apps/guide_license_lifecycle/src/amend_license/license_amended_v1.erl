%%% @doc license_amended_v1 event
%%% Emitted when any optional fields are amended on a license.
%%% Only non-undefined fields were changed.
%%% Covers both metadata and pricing fields.
-module(license_amended_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1,
         get_plugin_name/1, get_description/1, get_icon/1,
         get_github_repo/1, get_oci_image/1, get_org/1,
         get_version/1, get_manifest_tag/1, get_tags/1,
         get_homepage/1, get_min_daemon_version/1, get_publisher_identity/1,
         get_selling_formula/1, get_license_type/1,
         get_fee_cents/1, get_fee_currency/1,
         get_duration_days/1, get_node_limit/1,
         get_manifest_url/1, get_manifest_checksum/1, get_seller_signature/1,
         get_oci_image_verified/1, get_oci_image_digest/1,
         get_amended_at/1]).

-record(license_amended_v1, {
    license_id         :: binary(),
    %% Metadata
    plugin_name        :: binary() | undefined,
    description        :: binary() | undefined,
    icon               :: binary() | undefined,
    github_repo        :: binary() | undefined,
    oci_image          :: binary() | undefined,
    org                :: binary() | undefined,
    version            :: binary() | undefined,
    manifest_tag       :: binary() | undefined,
    tags               :: binary() | undefined,
    homepage           :: binary() | undefined,
    min_daemon_version :: binary() | undefined,
    publisher_identity :: binary() | undefined,
    %% Trust verification
    manifest_url       :: binary() | undefined,
    manifest_checksum  :: binary() | undefined,
    seller_signature   :: binary() | undefined,
    oci_image_verified :: 0 | 1 | undefined,
    oci_image_digest   :: binary() | undefined,
    %% Pricing
    selling_formula    :: binary() | undefined,
    license_type       :: binary() | undefined,
    fee_cents          :: non_neg_integer() | undefined,
    fee_currency       :: binary() | undefined,
    duration_days      :: non_neg_integer() | undefined,
    node_limit         :: non_neg_integer() | undefined,
    %% Timestamp
    amended_at         :: integer()
}).

-export_type([license_amended_v1/0]).
-opaque license_amended_v1() :: #license_amended_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_amended_v1().
new(#{license_id := LicenseId} = M) ->
    #license_amended_v1{
        license_id         = LicenseId,
        plugin_name        = maps:get(plugin_name, M, undefined),
        description        = maps:get(description, M, undefined),
        icon               = maps:get(icon, M, undefined),
        github_repo        = maps:get(github_repo, M, undefined),
        oci_image          = maps:get(oci_image, M, undefined),
        org                = maps:get(org, M, undefined),
        version            = maps:get(version, M, undefined),
        manifest_tag       = maps:get(manifest_tag, M, undefined),
        tags               = maps:get(tags, M, undefined),
        homepage           = maps:get(homepage, M, undefined),
        min_daemon_version = maps:get(min_daemon_version, M, undefined),
        publisher_identity = maps:get(publisher_identity, M, undefined),
        manifest_url       = maps:get(manifest_url, M, undefined),
        manifest_checksum  = maps:get(manifest_checksum, M, undefined),
        seller_signature   = maps:get(seller_signature, M, undefined),
        oci_image_verified = maps:get(oci_image_verified, M, undefined),
        oci_image_digest   = maps:get(oci_image_digest, M, undefined),
        selling_formula    = maps:get(selling_formula, M, undefined),
        license_type       = maps:get(license_type, M, undefined),
        fee_cents          = maps:get(fee_cents, M, undefined),
        fee_currency       = maps:get(fee_currency, M, undefined),
        duration_days      = maps:get(duration_days, M, undefined),
        node_limit         = maps:get(node_limit, M, undefined),
        amended_at         = erlang:system_time(millisecond)
    }.

-spec to_map(license_amended_v1()) -> map().
to_map(#license_amended_v1{} = E) ->
    Base = #{
        <<"event_type">> => <<"license_amended_v1">>,
        <<"license_id">> => E#license_amended_v1.license_id,
        <<"amended_at">> => E#license_amended_v1.amended_at
    },
    lists:foldl(fun({Key, Val}, Acc) -> maybe_put(Key, Val, Acc) end, Base, [
        {<<"plugin_name">>,        E#license_amended_v1.plugin_name},
        {<<"description">>,        E#license_amended_v1.description},
        {<<"icon">>,               E#license_amended_v1.icon},
        {<<"github_repo">>,        E#license_amended_v1.github_repo},
        {<<"oci_image">>,          E#license_amended_v1.oci_image},
        {<<"org">>,                E#license_amended_v1.org},
        {<<"version">>,            E#license_amended_v1.version},
        {<<"manifest_tag">>,       E#license_amended_v1.manifest_tag},
        {<<"tags">>,               E#license_amended_v1.tags},
        {<<"homepage">>,           E#license_amended_v1.homepage},
        {<<"min_daemon_version">>, E#license_amended_v1.min_daemon_version},
        {<<"publisher_identity">>, E#license_amended_v1.publisher_identity},
        {<<"manifest_url">>,       E#license_amended_v1.manifest_url},
        {<<"manifest_checksum">>,  E#license_amended_v1.manifest_checksum},
        {<<"seller_signature">>,   E#license_amended_v1.seller_signature},
        {<<"oci_image_verified">>, E#license_amended_v1.oci_image_verified},
        {<<"oci_image_digest">>,   E#license_amended_v1.oci_image_digest},
        {<<"selling_formula">>,    E#license_amended_v1.selling_formula},
        {<<"license_type">>,       E#license_amended_v1.license_type},
        {<<"fee_cents">>,          E#license_amended_v1.fee_cents},
        {<<"fee_currency">>,       E#license_amended_v1.fee_currency},
        {<<"duration_days">>,      E#license_amended_v1.duration_days},
        {<<"node_limit">>,         E#license_amended_v1.node_limit}
    ]).

-spec from_map(map()) -> {ok, license_amended_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_amended_v1{
                license_id         = LicenseId,
                plugin_name        = hecate_api_utils:get_field(plugin_name, Map),
                description        = hecate_api_utils:get_field(description, Map),
                icon               = hecate_api_utils:get_field(icon, Map),
                github_repo        = hecate_api_utils:get_field(github_repo, Map),
                oci_image          = hecate_api_utils:get_field(oci_image, Map),
                org                = hecate_api_utils:get_field(org, Map),
                version            = hecate_api_utils:get_field(version, Map),
                manifest_tag       = hecate_api_utils:get_field(manifest_tag, Map),
                tags               = hecate_api_utils:get_field(tags, Map),
                homepage           = hecate_api_utils:get_field(homepage, Map),
                min_daemon_version = hecate_api_utils:get_field(min_daemon_version, Map),
                publisher_identity = hecate_api_utils:get_field(publisher_identity, Map),
                manifest_url       = hecate_api_utils:get_field(manifest_url, Map),
                manifest_checksum  = hecate_api_utils:get_field(manifest_checksum, Map),
                seller_signature   = hecate_api_utils:get_field(seller_signature, Map),
                oci_image_verified = hecate_api_utils:get_field(oci_image_verified, Map),
                oci_image_digest   = hecate_api_utils:get_field(oci_image_digest, Map),
                selling_formula    = hecate_api_utils:get_field(selling_formula, Map),
                license_type       = hecate_api_utils:get_field(license_type, Map),
                fee_cents          = hecate_api_utils:get_field(fee_cents, Map),
                fee_currency       = hecate_api_utils:get_field(fee_currency, Map),
                duration_days      = hecate_api_utils:get_field(duration_days, Map),
                node_limit         = hecate_api_utils:get_field(node_limit, Map),
                amended_at         = hecate_api_utils:get_field(amended_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors

-spec get_license_id(license_amended_v1()) -> binary().
get_license_id(#license_amended_v1{license_id = V}) -> V.

-spec get_plugin_name(license_amended_v1()) -> binary() | undefined.
get_plugin_name(#license_amended_v1{plugin_name = V}) -> V.

-spec get_description(license_amended_v1()) -> binary() | undefined.
get_description(#license_amended_v1{description = V}) -> V.

-spec get_icon(license_amended_v1()) -> binary() | undefined.
get_icon(#license_amended_v1{icon = V}) -> V.

-spec get_github_repo(license_amended_v1()) -> binary() | undefined.
get_github_repo(#license_amended_v1{github_repo = V}) -> V.

-spec get_oci_image(license_amended_v1()) -> binary() | undefined.
get_oci_image(#license_amended_v1{oci_image = V}) -> V.

-spec get_org(license_amended_v1()) -> binary() | undefined.
get_org(#license_amended_v1{org = V}) -> V.

-spec get_version(license_amended_v1()) -> binary() | undefined.
get_version(#license_amended_v1{version = V}) -> V.

-spec get_manifest_tag(license_amended_v1()) -> binary() | undefined.
get_manifest_tag(#license_amended_v1{manifest_tag = V}) -> V.

-spec get_tags(license_amended_v1()) -> binary() | undefined.
get_tags(#license_amended_v1{tags = V}) -> V.

-spec get_homepage(license_amended_v1()) -> binary() | undefined.
get_homepage(#license_amended_v1{homepage = V}) -> V.

-spec get_min_daemon_version(license_amended_v1()) -> binary() | undefined.
get_min_daemon_version(#license_amended_v1{min_daemon_version = V}) -> V.

-spec get_publisher_identity(license_amended_v1()) -> binary() | undefined.
get_publisher_identity(#license_amended_v1{publisher_identity = V}) -> V.

-spec get_selling_formula(license_amended_v1()) -> binary() | undefined.
get_selling_formula(#license_amended_v1{selling_formula = V}) -> V.

-spec get_license_type(license_amended_v1()) -> binary() | undefined.
get_license_type(#license_amended_v1{license_type = V}) -> V.

-spec get_fee_cents(license_amended_v1()) -> non_neg_integer() | undefined.
get_fee_cents(#license_amended_v1{fee_cents = V}) -> V.

-spec get_fee_currency(license_amended_v1()) -> binary() | undefined.
get_fee_currency(#license_amended_v1{fee_currency = V}) -> V.

-spec get_duration_days(license_amended_v1()) -> non_neg_integer() | undefined.
get_duration_days(#license_amended_v1{duration_days = V}) -> V.

-spec get_node_limit(license_amended_v1()) -> non_neg_integer() | undefined.
get_node_limit(#license_amended_v1{node_limit = V}) -> V.

-spec get_manifest_url(license_amended_v1()) -> binary() | undefined.
get_manifest_url(#license_amended_v1{manifest_url = V}) -> V.

-spec get_manifest_checksum(license_amended_v1()) -> binary() | undefined.
get_manifest_checksum(#license_amended_v1{manifest_checksum = V}) -> V.

-spec get_seller_signature(license_amended_v1()) -> binary() | undefined.
get_seller_signature(#license_amended_v1{seller_signature = V}) -> V.

-spec get_oci_image_verified(license_amended_v1()) -> 0 | 1 | undefined.
get_oci_image_verified(#license_amended_v1{oci_image_verified = V}) -> V.

-spec get_oci_image_digest(license_amended_v1()) -> binary() | undefined.
get_oci_image_digest(#license_amended_v1{oci_image_digest = V}) -> V.

-spec get_amended_at(license_amended_v1()) -> integer().
get_amended_at(#license_amended_v1{amended_at = V}) -> V.

%% Internal

maybe_put(_Key, undefined, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.
