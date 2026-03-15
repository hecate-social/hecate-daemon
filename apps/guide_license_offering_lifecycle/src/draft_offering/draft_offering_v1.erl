%%% @doc draft_offering_v1 command
%%% Saves work in progress on an offering (internal/programmatic).
%%% All fields except offering_id are optional.
-module(draft_offering_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_offering_id/1,
         get_plugin_name/1, get_description/1, get_icon/1, get_group_name/1, get_group_icon/1,
         get_github_repo/1, get_homepage/1, get_tags/1,
         get_oci_image/1, get_org/1, get_version/1, get_manifest_tag/1,
         get_min_daemon_version/1, get_publisher_identity/1,
         get_selling_formula/1, get_license_type/1,
         get_fee_cents/1, get_fee_currency/1,
         get_duration_days/1, get_node_limit/1,
         get_manifest_url/1, get_manifest_checksum/1, get_author_signature/1,
         get_oci_image_verified/1, get_oci_image_digest/1]).

-record(draft_offering_v1, {
    offering_id        :: binary(),
    %% Marketing
    plugin_name        :: binary() | undefined,
    description        :: binary() | undefined,
    icon               :: binary() | undefined,
    group_name         :: binary() | undefined,
    group_icon         :: binary() | undefined,
    github_repo        :: binary() | undefined,
    homepage           :: binary() | undefined,
    tags               :: binary() | undefined,
    %% Technical
    oci_image          :: binary() | undefined,
    org                :: binary() | undefined,
    version            :: binary() | undefined,
    manifest_tag       :: binary() | undefined,
    min_daemon_version :: binary() | undefined,
    publisher_identity :: binary() | undefined,
    %% Commercial
    selling_formula    :: binary() | undefined,
    license_type       :: binary() | undefined,
    fee_cents          :: non_neg_integer() | undefined,
    fee_currency       :: binary() | undefined,
    duration_days      :: non_neg_integer() | undefined,
    node_limit         :: non_neg_integer() | undefined,
    %% Trust verification
    manifest_url       :: binary() | undefined,
    manifest_checksum  :: binary() | undefined,
    author_signature   :: binary() | undefined,
    oci_image_verified :: 0 | 1 | undefined,
    oci_image_digest   :: binary() | undefined
}).

-export_type([draft_offering_v1/0]).
-opaque draft_offering_v1() :: #draft_offering_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, draft_offering_v1()} | {error, term()}.
command_type() -> draft_offering_v1.

new(#{offering_id := OfferingId} = M) ->
    {ok, #draft_offering_v1{
        offering_id = OfferingId,
        plugin_name = maps:get(plugin_name, M, undefined),
        description = maps:get(description, M, undefined),
        icon = maps:get(icon, M, undefined),
        group_name = maps:get(group_name, M, undefined),
        group_icon = maps:get(group_icon, M, undefined),
        github_repo = maps:get(github_repo, M, undefined),
        homepage = maps:get(homepage, M, undefined),
        tags = maps:get(tags, M, undefined),
        oci_image = maps:get(oci_image, M, undefined),
        org = maps:get(org, M, undefined),
        version = maps:get(version, M, undefined),
        manifest_tag = maps:get(manifest_tag, M, undefined),
        min_daemon_version = maps:get(min_daemon_version, M, undefined),
        publisher_identity = maps:get(publisher_identity, M, undefined),
        selling_formula = maps:get(selling_formula, M, undefined),
        license_type = maps:get(license_type, M, undefined),
        fee_cents = maps:get(fee_cents, M, undefined),
        fee_currency = maps:get(fee_currency, M, undefined),
        duration_days = maps:get(duration_days, M, undefined),
        node_limit = maps:get(node_limit, M, undefined),
        manifest_url = maps:get(manifest_url, M, undefined),
        manifest_checksum = maps:get(manifest_checksum, M, undefined),
        author_signature = maps:get(author_signature, M, undefined),
        oci_image_verified = maps:get(oci_image_verified, M, undefined),
        oci_image_digest = maps:get(oci_image_digest, M, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(draft_offering_v1()) -> {ok, draft_offering_v1()} | {error, term()}.
validate(#draft_offering_v1{offering_id = OfferingId}) when
    not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, invalid_offering_id};
validate(#draft_offering_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(draft_offering_v1()) -> map().
to_map(#draft_offering_v1{} = Cmd) ->
    Base = #{
        command_type => <<"draft_offering">>,
        offering_id => Cmd#draft_offering_v1.offering_id
    },
    lists:foldl(fun({Key, Val}, Acc) -> maybe_put(Key, Val, Acc) end, Base, [
        {<<"plugin_name">>,        Cmd#draft_offering_v1.plugin_name},
        {<<"description">>,        Cmd#draft_offering_v1.description},
        {<<"icon">>,               Cmd#draft_offering_v1.icon},
        {<<"group_name">>,         Cmd#draft_offering_v1.group_name},
        {<<"group_icon">>,         Cmd#draft_offering_v1.group_icon},
        {<<"github_repo">>,        Cmd#draft_offering_v1.github_repo},
        {<<"homepage">>,           Cmd#draft_offering_v1.homepage},
        {<<"tags">>,               Cmd#draft_offering_v1.tags},
        {<<"oci_image">>,          Cmd#draft_offering_v1.oci_image},
        {<<"org">>,                Cmd#draft_offering_v1.org},
        {<<"version">>,            Cmd#draft_offering_v1.version},
        {<<"manifest_tag">>,       Cmd#draft_offering_v1.manifest_tag},
        {<<"min_daemon_version">>, Cmd#draft_offering_v1.min_daemon_version},
        {<<"publisher_identity">>, Cmd#draft_offering_v1.publisher_identity},
        {<<"selling_formula">>,    Cmd#draft_offering_v1.selling_formula},
        {<<"license_type">>,       Cmd#draft_offering_v1.license_type},
        {<<"fee_cents">>,          Cmd#draft_offering_v1.fee_cents},
        {<<"fee_currency">>,       Cmd#draft_offering_v1.fee_currency},
        {<<"duration_days">>,      Cmd#draft_offering_v1.duration_days},
        {<<"node_limit">>,         Cmd#draft_offering_v1.node_limit},
        {<<"manifest_url">>,       Cmd#draft_offering_v1.manifest_url},
        {<<"manifest_checksum">>,  Cmd#draft_offering_v1.manifest_checksum},
        {<<"author_signature">>,   Cmd#draft_offering_v1.author_signature},
        {<<"oci_image_verified">>, Cmd#draft_offering_v1.oci_image_verified},
        {<<"oci_image_digest">>,   Cmd#draft_offering_v1.oci_image_digest}
    ]).

-spec from_map(map()) -> {ok, draft_offering_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #draft_offering_v1{
                offering_id = OfferingId,
                plugin_name = hecate_api_utils:get_field(plugin_name, Map),
                description = hecate_api_utils:get_field(description, Map),
                icon = hecate_api_utils:get_field(icon, Map),
                group_name = hecate_api_utils:get_field(group_name, Map),
                group_icon = hecate_api_utils:get_field(group_icon, Map),
                github_repo = hecate_api_utils:get_field(github_repo, Map),
                homepage = hecate_api_utils:get_field(homepage, Map),
                tags = hecate_api_utils:get_field(tags, Map),
                oci_image = hecate_api_utils:get_field(oci_image, Map),
                org = hecate_api_utils:get_field(org, Map),
                version = hecate_api_utils:get_field(version, Map),
                manifest_tag = hecate_api_utils:get_field(manifest_tag, Map),
                min_daemon_version = hecate_api_utils:get_field(min_daemon_version, Map),
                publisher_identity = hecate_api_utils:get_field(publisher_identity, Map),
                selling_formula = hecate_api_utils:get_field(selling_formula, Map),
                license_type = hecate_api_utils:get_field(license_type, Map),
                fee_cents = hecate_api_utils:get_field(fee_cents, Map),
                fee_currency = hecate_api_utils:get_field(fee_currency, Map),
                duration_days = hecate_api_utils:get_field(duration_days, Map),
                node_limit = hecate_api_utils:get_field(node_limit, Map),
                manifest_url = hecate_api_utils:get_field(manifest_url, Map),
                manifest_checksum = hecate_api_utils:get_field(manifest_checksum, Map),
                author_signature = hecate_api_utils:get_field(author_signature, Map),
                oci_image_verified = hecate_api_utils:get_field(oci_image_verified, Map),
                oci_image_digest = hecate_api_utils:get_field(oci_image_digest, Map)
            }}
    end.

%% Accessors
-spec get_offering_id(draft_offering_v1()) -> binary().
get_offering_id(#draft_offering_v1{offering_id = V}) -> V.

-spec get_plugin_name(draft_offering_v1()) -> binary() | undefined.
get_plugin_name(#draft_offering_v1{plugin_name = V}) -> V.

-spec get_description(draft_offering_v1()) -> binary() | undefined.
get_description(#draft_offering_v1{description = V}) -> V.

-spec get_icon(draft_offering_v1()) -> binary() | undefined.
get_icon(#draft_offering_v1{icon = V}) -> V.

-spec get_group_name(draft_offering_v1()) -> binary() | undefined.
get_group_name(#draft_offering_v1{group_name = V}) -> V.

-spec get_group_icon(draft_offering_v1()) -> binary() | undefined.
get_group_icon(#draft_offering_v1{group_icon = V}) -> V.

-spec get_github_repo(draft_offering_v1()) -> binary() | undefined.
get_github_repo(#draft_offering_v1{github_repo = V}) -> V.

-spec get_homepage(draft_offering_v1()) -> binary() | undefined.
get_homepage(#draft_offering_v1{homepage = V}) -> V.

-spec get_tags(draft_offering_v1()) -> binary() | undefined.
get_tags(#draft_offering_v1{tags = V}) -> V.

-spec get_oci_image(draft_offering_v1()) -> binary() | undefined.
get_oci_image(#draft_offering_v1{oci_image = V}) -> V.

-spec get_org(draft_offering_v1()) -> binary() | undefined.
get_org(#draft_offering_v1{org = V}) -> V.

-spec get_version(draft_offering_v1()) -> binary() | undefined.
get_version(#draft_offering_v1{version = V}) -> V.

-spec get_manifest_tag(draft_offering_v1()) -> binary() | undefined.
get_manifest_tag(#draft_offering_v1{manifest_tag = V}) -> V.

-spec get_min_daemon_version(draft_offering_v1()) -> binary() | undefined.
get_min_daemon_version(#draft_offering_v1{min_daemon_version = V}) -> V.

-spec get_publisher_identity(draft_offering_v1()) -> binary() | undefined.
get_publisher_identity(#draft_offering_v1{publisher_identity = V}) -> V.

-spec get_selling_formula(draft_offering_v1()) -> binary() | undefined.
get_selling_formula(#draft_offering_v1{selling_formula = V}) -> V.

-spec get_license_type(draft_offering_v1()) -> binary() | undefined.
get_license_type(#draft_offering_v1{license_type = V}) -> V.

-spec get_fee_cents(draft_offering_v1()) -> non_neg_integer() | undefined.
get_fee_cents(#draft_offering_v1{fee_cents = V}) -> V.

-spec get_fee_currency(draft_offering_v1()) -> binary() | undefined.
get_fee_currency(#draft_offering_v1{fee_currency = V}) -> V.

-spec get_duration_days(draft_offering_v1()) -> non_neg_integer() | undefined.
get_duration_days(#draft_offering_v1{duration_days = V}) -> V.

-spec get_node_limit(draft_offering_v1()) -> non_neg_integer() | undefined.
get_node_limit(#draft_offering_v1{node_limit = V}) -> V.

-spec get_manifest_url(draft_offering_v1()) -> binary() | undefined.
get_manifest_url(#draft_offering_v1{manifest_url = V}) -> V.

-spec get_manifest_checksum(draft_offering_v1()) -> binary() | undefined.
get_manifest_checksum(#draft_offering_v1{manifest_checksum = V}) -> V.

-spec get_author_signature(draft_offering_v1()) -> binary() | undefined.
get_author_signature(#draft_offering_v1{author_signature = V}) -> V.

-spec get_oci_image_verified(draft_offering_v1()) -> 0 | 1 | undefined.
get_oci_image_verified(#draft_offering_v1{oci_image_verified = V}) -> V.

-spec get_oci_image_digest(draft_offering_v1()) -> binary() | undefined.
get_oci_image_digest(#draft_offering_v1{oci_image_digest = V}) -> V.

%% Internal
maybe_put(_Key, undefined, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.
