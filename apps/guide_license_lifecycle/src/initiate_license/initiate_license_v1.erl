%%% @doc initiate_license_v1 command
%%% Birth event for seller-side license creation.
-module(initiate_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_plugin_id/1, get_plugin_name/1,
         get_description/1, get_icon/1, get_github_repo/1,
         get_oci_image/1, get_selling_formula/1, get_seller_id/1,
         get_org/1, get_version/1, get_manifest_tag/1, get_tags/1,
         get_homepage/1, get_min_daemon_version/1, get_publisher_identity/1]).

-record(initiate_license_v1, {
    license_id      :: binary(),
    plugin_id       :: binary(),
    plugin_name     :: binary() | undefined,
    description     :: binary() | undefined,
    icon            :: binary() | undefined,
    github_repo     :: binary() | undefined,
    oci_image       :: binary() | undefined,
    selling_formula :: binary() | undefined,
    seller_id       :: binary(),
    org             :: binary() | undefined,
    version         :: binary() | undefined,
    manifest_tag    :: binary() | undefined,
    tags            :: binary() | undefined,
    homepage        :: binary() | undefined,
    min_daemon_version :: binary() | undefined,
    publisher_identity :: binary() | undefined
}).

-export_type([initiate_license_v1/0]).
-opaque initiate_license_v1() :: #initiate_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_license_v1()} | {error, term()}.
new(#{seller_id := SellerId, plugin_id := PluginId} = Params) ->
    LicenseId = <<"license-", SellerId/binary, "-", PluginId/binary>>,
    {ok, #initiate_license_v1{
        license_id = LicenseId,
        plugin_id = PluginId,
        plugin_name = maps:get(plugin_name, Params, undefined),
        description = maps:get(description, Params, undefined),
        icon = maps:get(icon, Params, undefined),
        github_repo = maps:get(github_repo, Params, undefined),
        oci_image = maps:get(oci_image, Params, undefined),
        selling_formula = maps:get(selling_formula, Params, undefined),
        seller_id = SellerId,
        org = maps:get(org, Params, undefined),
        version = maps:get(version, Params, undefined),
        manifest_tag = maps:get(manifest_tag, Params, undefined),
        tags = maps:get(tags, Params, undefined),
        homepage = maps:get(homepage, Params, undefined),
        min_daemon_version = maps:get(min_daemon_version, Params, undefined),
        publisher_identity = maps:get(publisher_identity, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_license_v1()) -> {ok, initiate_license_v1()} | {error, term()}.
validate(#initiate_license_v1{seller_id = SellerId}) when
    not is_binary(SellerId); byte_size(SellerId) =:= 0 ->
    {error, invalid_seller_id};
validate(#initiate_license_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#initiate_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_license_v1()) -> map().
to_map(#initiate_license_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"initiate_license">>,
        <<"license_id">> => Cmd#initiate_license_v1.license_id,
        <<"plugin_id">> => Cmd#initiate_license_v1.plugin_id,
        <<"plugin_name">> => Cmd#initiate_license_v1.plugin_name,
        <<"description">> => Cmd#initiate_license_v1.description,
        <<"icon">> => Cmd#initiate_license_v1.icon,
        <<"github_repo">> => Cmd#initiate_license_v1.github_repo,
        <<"oci_image">> => Cmd#initiate_license_v1.oci_image,
        <<"selling_formula">> => Cmd#initiate_license_v1.selling_formula,
        <<"seller_id">> => Cmd#initiate_license_v1.seller_id,
        <<"org">> => Cmd#initiate_license_v1.org,
        <<"version">> => Cmd#initiate_license_v1.version,
        <<"manifest_tag">> => Cmd#initiate_license_v1.manifest_tag,
        <<"tags">> => Cmd#initiate_license_v1.tags,
        <<"homepage">> => Cmd#initiate_license_v1.homepage,
        <<"min_daemon_version">> => Cmd#initiate_license_v1.min_daemon_version,
        <<"publisher_identity">> => Cmd#initiate_license_v1.publisher_identity
    }.

-spec from_map(map()) -> {ok, initiate_license_v1()} | {error, term()}.
from_map(Map) ->
    SellerId = hecate_api_utils:get_field(seller_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case {SellerId, PluginId} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            LicenseId = <<"license-", SellerId/binary, "-", PluginId/binary>>,
            {ok, #initiate_license_v1{
                license_id = LicenseId,
                plugin_id = PluginId,
                plugin_name = hecate_api_utils:get_field(plugin_name, Map, undefined),
                description = hecate_api_utils:get_field(description, Map, undefined),
                icon = hecate_api_utils:get_field(icon, Map, undefined),
                github_repo = hecate_api_utils:get_field(github_repo, Map, undefined),
                oci_image = hecate_api_utils:get_field(oci_image, Map, undefined),
                selling_formula = hecate_api_utils:get_field(selling_formula, Map, undefined),
                seller_id = SellerId,
                org = hecate_api_utils:get_field(org, Map, undefined),
                version = hecate_api_utils:get_field(version, Map, undefined),
                manifest_tag = hecate_api_utils:get_field(manifest_tag, Map, undefined),
                tags = hecate_api_utils:get_field(tags, Map, undefined),
                homepage = hecate_api_utils:get_field(homepage, Map, undefined),
                min_daemon_version = hecate_api_utils:get_field(min_daemon_version, Map, undefined),
                publisher_identity = hecate_api_utils:get_field(publisher_identity, Map, undefined)
            }}
    end.

%% Accessors
-spec get_license_id(initiate_license_v1()) -> binary().
get_license_id(#initiate_license_v1{license_id = V}) -> V.

-spec get_plugin_id(initiate_license_v1()) -> binary().
get_plugin_id(#initiate_license_v1{plugin_id = V}) -> V.

-spec get_plugin_name(initiate_license_v1()) -> binary() | undefined.
get_plugin_name(#initiate_license_v1{plugin_name = V}) -> V.

-spec get_description(initiate_license_v1()) -> binary() | undefined.
get_description(#initiate_license_v1{description = V}) -> V.

-spec get_icon(initiate_license_v1()) -> binary() | undefined.
get_icon(#initiate_license_v1{icon = V}) -> V.

-spec get_github_repo(initiate_license_v1()) -> binary() | undefined.
get_github_repo(#initiate_license_v1{github_repo = V}) -> V.

-spec get_oci_image(initiate_license_v1()) -> binary() | undefined.
get_oci_image(#initiate_license_v1{oci_image = V}) -> V.

-spec get_selling_formula(initiate_license_v1()) -> binary() | undefined.
get_selling_formula(#initiate_license_v1{selling_formula = V}) -> V.

-spec get_seller_id(initiate_license_v1()) -> binary().
get_seller_id(#initiate_license_v1{seller_id = V}) -> V.

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
