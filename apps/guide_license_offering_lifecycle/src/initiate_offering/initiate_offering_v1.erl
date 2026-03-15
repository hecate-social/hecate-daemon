%%% @doc initiate_offering_v1 command
%%% Birth event for author-side offering creation.
-module(initiate_offering_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_offering_id/1, get_plugin_id/1, get_author_id/1,
         get_plugin_name/1, get_display_name/1, get_description/1, get_icon/1, get_group_name/1, get_group_icon/1,
         get_github_repo/1, get_homepage/1, get_tags/1,
         get_oci_image/1, get_package_url/1, get_plugin_type/1, get_callback_module/1,
         get_org/1, get_version/1, get_manifest_tag/1,
         get_min_daemon_version/1, get_publisher_identity/1,
         get_selling_formula/1, get_license_type/1,
         get_fee_cents/1, get_fee_currency/1,
         get_duration_days/1, get_node_limit/1,
         get_manifest_url/1, get_manifest_checksum/1, get_author_signature/1,
         get_oci_image_verified/1, get_oci_image_digest/1]).

-record(initiate_offering_v1, {
    offering_id        :: binary(),
    plugin_id          :: binary(),
    author_id          :: binary(),
    %% Marketing
    plugin_name        :: binary() | undefined,
    display_name       :: binary() | undefined,
    description        :: binary() | undefined,
    icon               :: binary() | undefined,
    group_name         :: binary() | undefined,
    group_icon         :: binary() | undefined,
    github_repo        :: binary() | undefined,
    homepage           :: binary() | undefined,
    tags               :: binary() | undefined,
    %% Technical
    oci_image          :: binary() | undefined,
    package_url        :: binary() | undefined,
    plugin_type        :: binary() | undefined,
    callback_module    :: binary() | undefined,
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

-export_type([initiate_offering_v1/0]).
-opaque initiate_offering_v1() :: #initiate_offering_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_offering_v1()} | {error, term()}.
command_type() -> initiate_offering_v1.

new(#{author_id := AuthorId, plugin_id := PluginId} = Params) ->
    OfferingId = <<"offering-", AuthorId/binary, "-", PluginId/binary>>,
    {ok, #initiate_offering_v1{
        offering_id = OfferingId,
        plugin_id = PluginId,
        author_id = AuthorId,
        plugin_name = maps:get(plugin_name, Params, undefined),
        display_name = maps:get(display_name, Params, undefined),
        description = maps:get(description, Params, undefined),
        icon = maps:get(icon, Params, undefined),
        group_name = maps:get(group_name, Params, undefined),
        group_icon = maps:get(group_icon, Params, undefined),
        github_repo = maps:get(github_repo, Params, undefined),
        homepage = maps:get(homepage, Params, undefined),
        tags = maps:get(tags, Params, undefined),
        oci_image = maps:get(oci_image, Params, undefined),
        package_url = maps:get(package_url, Params, undefined),
        plugin_type = maps:get(plugin_type, Params, undefined),
        callback_module = maps:get(callback_module, Params, undefined),
        org = maps:get(org, Params, undefined),
        version = maps:get(version, Params, undefined),
        manifest_tag = maps:get(manifest_tag, Params, undefined),
        min_daemon_version = maps:get(min_daemon_version, Params, undefined),
        publisher_identity = maps:get(publisher_identity, Params, undefined),
        selling_formula = maps:get(selling_formula, Params, undefined),
        license_type = maps:get(license_type, Params, undefined),
        fee_cents = maps:get(fee_cents, Params, undefined),
        fee_currency = maps:get(fee_currency, Params, undefined),
        duration_days = maps:get(duration_days, Params, undefined),
        node_limit = maps:get(node_limit, Params, undefined),
        manifest_url = maps:get(manifest_url, Params, undefined),
        manifest_checksum = maps:get(manifest_checksum, Params, undefined),
        author_signature = maps:get(author_signature, Params, undefined),
        oci_image_verified = maps:get(oci_image_verified, Params, undefined),
        oci_image_digest = maps:get(oci_image_digest, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_offering_v1()) -> {ok, initiate_offering_v1()} | {error, term()}.
validate(#initiate_offering_v1{author_id = AuthorId}) when
    not is_binary(AuthorId); byte_size(AuthorId) =:= 0 ->
    {error, invalid_author_id};
validate(#initiate_offering_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#initiate_offering_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_offering_v1()) -> map().
to_map(#initiate_offering_v1{} = Cmd) ->
    #{
        command_type => <<"initiate_offering">>,
        offering_id => Cmd#initiate_offering_v1.offering_id,
        plugin_id => Cmd#initiate_offering_v1.plugin_id,
        author_id => Cmd#initiate_offering_v1.author_id,
        plugin_name => Cmd#initiate_offering_v1.plugin_name,
        display_name => Cmd#initiate_offering_v1.display_name,
        description => Cmd#initiate_offering_v1.description,
        icon => Cmd#initiate_offering_v1.icon,
        group_name => Cmd#initiate_offering_v1.group_name,
        group_icon => Cmd#initiate_offering_v1.group_icon,
        github_repo => Cmd#initiate_offering_v1.github_repo,
        homepage => Cmd#initiate_offering_v1.homepage,
        tags => Cmd#initiate_offering_v1.tags,
        oci_image => Cmd#initiate_offering_v1.oci_image,
        package_url => Cmd#initiate_offering_v1.package_url,
        plugin_type => Cmd#initiate_offering_v1.plugin_type,
        callback_module => Cmd#initiate_offering_v1.callback_module,
        org => Cmd#initiate_offering_v1.org,
        version => Cmd#initiate_offering_v1.version,
        manifest_tag => Cmd#initiate_offering_v1.manifest_tag,
        min_daemon_version => Cmd#initiate_offering_v1.min_daemon_version,
        publisher_identity => Cmd#initiate_offering_v1.publisher_identity,
        selling_formula => Cmd#initiate_offering_v1.selling_formula,
        license_type => Cmd#initiate_offering_v1.license_type,
        fee_cents => Cmd#initiate_offering_v1.fee_cents,
        fee_currency => Cmd#initiate_offering_v1.fee_currency,
        duration_days => Cmd#initiate_offering_v1.duration_days,
        node_limit => Cmd#initiate_offering_v1.node_limit,
        manifest_url => Cmd#initiate_offering_v1.manifest_url,
        manifest_checksum => Cmd#initiate_offering_v1.manifest_checksum,
        author_signature => Cmd#initiate_offering_v1.author_signature,
        oci_image_verified => Cmd#initiate_offering_v1.oci_image_verified,
        oci_image_digest => Cmd#initiate_offering_v1.oci_image_digest
    }.

-spec from_map(map()) -> {ok, initiate_offering_v1()} | {error, term()}.
from_map(Map) ->
    AuthorId = hecate_api_utils:get_field(author_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case {AuthorId, PluginId} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            OfferingId = <<"offering-", AuthorId/binary, "-", PluginId/binary>>,
            {ok, #initiate_offering_v1{
                offering_id = OfferingId,
                plugin_id = PluginId,
                author_id = AuthorId,
                plugin_name = hecate_api_utils:get_field(plugin_name, Map, undefined),
                display_name = hecate_api_utils:get_field(display_name, Map, undefined),
                description = hecate_api_utils:get_field(description, Map, undefined),
                icon = hecate_api_utils:get_field(icon, Map, undefined),
                group_name = hecate_api_utils:get_field(group_name, Map, undefined),
                group_icon = hecate_api_utils:get_field(group_icon, Map, undefined),
                github_repo = hecate_api_utils:get_field(github_repo, Map, undefined),
                homepage = hecate_api_utils:get_field(homepage, Map, undefined),
                tags = hecate_api_utils:get_field(tags, Map, undefined),
                oci_image = hecate_api_utils:get_field(oci_image, Map, undefined),
                package_url = hecate_api_utils:get_field(package_url, Map, undefined),
                plugin_type = hecate_api_utils:get_field(plugin_type, Map, undefined),
                callback_module = hecate_api_utils:get_field(callback_module, Map, undefined),
                org = hecate_api_utils:get_field(org, Map, undefined),
                version = hecate_api_utils:get_field(version, Map, undefined),
                manifest_tag = hecate_api_utils:get_field(manifest_tag, Map, undefined),
                min_daemon_version = hecate_api_utils:get_field(min_daemon_version, Map, undefined),
                publisher_identity = hecate_api_utils:get_field(publisher_identity, Map, undefined),
                selling_formula = hecate_api_utils:get_field(selling_formula, Map, undefined),
                license_type = hecate_api_utils:get_field(license_type, Map, undefined),
                fee_cents = hecate_api_utils:get_field(fee_cents, Map, undefined),
                fee_currency = hecate_api_utils:get_field(fee_currency, Map, undefined),
                duration_days = hecate_api_utils:get_field(duration_days, Map, undefined),
                node_limit = hecate_api_utils:get_field(node_limit, Map, undefined),
                manifest_url = hecate_api_utils:get_field(manifest_url, Map, undefined),
                manifest_checksum = hecate_api_utils:get_field(manifest_checksum, Map, undefined),
                author_signature = hecate_api_utils:get_field(author_signature, Map, undefined),
                oci_image_verified = hecate_api_utils:get_field(oci_image_verified, Map, undefined),
                oci_image_digest = hecate_api_utils:get_field(oci_image_digest, Map, undefined)
            }}
    end.

%% Accessors
-spec get_offering_id(initiate_offering_v1()) -> binary().
get_offering_id(#initiate_offering_v1{offering_id = V}) -> V.

-spec get_plugin_id(initiate_offering_v1()) -> binary().
get_plugin_id(#initiate_offering_v1{plugin_id = V}) -> V.

-spec get_author_id(initiate_offering_v1()) -> binary().
get_author_id(#initiate_offering_v1{author_id = V}) -> V.

-spec get_plugin_name(initiate_offering_v1()) -> binary() | undefined.
get_plugin_name(#initiate_offering_v1{plugin_name = V}) -> V.

-spec get_display_name(initiate_offering_v1()) -> binary() | undefined.
get_display_name(#initiate_offering_v1{display_name = V}) -> V.

-spec get_description(initiate_offering_v1()) -> binary() | undefined.
get_description(#initiate_offering_v1{description = V}) -> V.

-spec get_icon(initiate_offering_v1()) -> binary() | undefined.
get_icon(#initiate_offering_v1{icon = V}) -> V.

-spec get_group_name(initiate_offering_v1()) -> binary() | undefined.
get_group_name(#initiate_offering_v1{group_name = V}) -> V.

-spec get_group_icon(initiate_offering_v1()) -> binary() | undefined.
get_group_icon(#initiate_offering_v1{group_icon = V}) -> V.

-spec get_github_repo(initiate_offering_v1()) -> binary() | undefined.
get_github_repo(#initiate_offering_v1{github_repo = V}) -> V.

-spec get_homepage(initiate_offering_v1()) -> binary() | undefined.
get_homepage(#initiate_offering_v1{homepage = V}) -> V.

-spec get_tags(initiate_offering_v1()) -> binary() | undefined.
get_tags(#initiate_offering_v1{tags = V}) -> V.

-spec get_oci_image(initiate_offering_v1()) -> binary() | undefined.
get_oci_image(#initiate_offering_v1{oci_image = V}) -> V.

-spec get_package_url(initiate_offering_v1()) -> binary() | undefined.
get_package_url(#initiate_offering_v1{package_url = V}) -> V.

-spec get_plugin_type(initiate_offering_v1()) -> binary() | undefined.
get_plugin_type(#initiate_offering_v1{plugin_type = V}) -> V.

-spec get_callback_module(initiate_offering_v1()) -> binary() | undefined.
get_callback_module(#initiate_offering_v1{callback_module = V}) -> V.

-spec get_org(initiate_offering_v1()) -> binary() | undefined.
get_org(#initiate_offering_v1{org = V}) -> V.

-spec get_version(initiate_offering_v1()) -> binary() | undefined.
get_version(#initiate_offering_v1{version = V}) -> V.

-spec get_manifest_tag(initiate_offering_v1()) -> binary() | undefined.
get_manifest_tag(#initiate_offering_v1{manifest_tag = V}) -> V.

-spec get_min_daemon_version(initiate_offering_v1()) -> binary() | undefined.
get_min_daemon_version(#initiate_offering_v1{min_daemon_version = V}) -> V.

-spec get_publisher_identity(initiate_offering_v1()) -> binary() | undefined.
get_publisher_identity(#initiate_offering_v1{publisher_identity = V}) -> V.

-spec get_selling_formula(initiate_offering_v1()) -> binary() | undefined.
get_selling_formula(#initiate_offering_v1{selling_formula = V}) -> V.

-spec get_license_type(initiate_offering_v1()) -> binary() | undefined.
get_license_type(#initiate_offering_v1{license_type = V}) -> V.

-spec get_fee_cents(initiate_offering_v1()) -> non_neg_integer() | undefined.
get_fee_cents(#initiate_offering_v1{fee_cents = V}) -> V.

-spec get_fee_currency(initiate_offering_v1()) -> binary() | undefined.
get_fee_currency(#initiate_offering_v1{fee_currency = V}) -> V.

-spec get_duration_days(initiate_offering_v1()) -> non_neg_integer() | undefined.
get_duration_days(#initiate_offering_v1{duration_days = V}) -> V.

-spec get_node_limit(initiate_offering_v1()) -> non_neg_integer() | undefined.
get_node_limit(#initiate_offering_v1{node_limit = V}) -> V.

-spec get_manifest_url(initiate_offering_v1()) -> binary() | undefined.
get_manifest_url(#initiate_offering_v1{manifest_url = V}) -> V.

-spec get_manifest_checksum(initiate_offering_v1()) -> binary() | undefined.
get_manifest_checksum(#initiate_offering_v1{manifest_checksum = V}) -> V.

-spec get_author_signature(initiate_offering_v1()) -> binary() | undefined.
get_author_signature(#initiate_offering_v1{author_signature = V}) -> V.

-spec get_oci_image_verified(initiate_offering_v1()) -> 0 | 1 | undefined.
get_oci_image_verified(#initiate_offering_v1{oci_image_verified = V}) -> V.

-spec get_oci_image_digest(initiate_offering_v1()) -> binary() | undefined.
get_oci_image_digest(#initiate_offering_v1{oci_image_digest = V}) -> V.
