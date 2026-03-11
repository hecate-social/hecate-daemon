%%% @doc license_granted_v1 event
%%% Emitted when a license is activated (free or paid path).
%%% Carries install-relevant fields from aggregate state so downstream
%%% PMs (e.g., on_license_granted_install_plugin) are self-contained.
-module(license_granted_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_grant_reason/1, get_granted_at/1,
         get_plugin_id/1, get_plugin_name/1, get_display_name/1, get_oci_image/1,
         get_version/1, get_icon/1, get_group_name/1, get_group_icon/1,
         get_plugin_type/1, get_callback_module/1,
         get_package_url/1]).

-record(license_granted_v1, {
    license_id   :: binary(),
    grant_reason :: binary() | undefined,
    granted_at   :: integer(),
    %% Install-relevant fields echoed from aggregate state
    plugin_id    :: binary() | undefined,
    plugin_name  :: binary() | undefined,
    display_name :: binary() | undefined,
    oci_image    :: binary() | undefined,
    version      :: binary() | undefined,
    icon         :: binary() | undefined,
    group_name   :: binary() | undefined,
    group_icon   :: binary() | undefined,
    plugin_type  :: binary() | undefined,
    callback_module :: binary() | undefined,
    package_url  :: binary() | undefined
}).

-export_type([license_granted_v1/0]).
-opaque license_granted_v1() :: #license_granted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_granted_v1().
new(#{license_id := LicenseId} = Params) ->
    #license_granted_v1{
        license_id   = LicenseId,
        grant_reason = maps:get(grant_reason, Params, undefined),
        granted_at   = erlang:system_time(millisecond),
        plugin_id    = maps:get(plugin_id, Params, undefined),
        plugin_name  = maps:get(plugin_name, Params, undefined),
        display_name = maps:get(display_name, Params, undefined),
        oci_image    = maps:get(oci_image, Params, undefined),
        version      = maps:get(version, Params, undefined),
        icon         = maps:get(icon, Params, undefined),
        group_name   = maps:get(group_name, Params, undefined),
        group_icon   = maps:get(group_icon, Params, undefined),
        plugin_type  = maps:get(plugin_type, Params, undefined),
        callback_module = maps:get(callback_module, Params, undefined),
        package_url  = maps:get(package_url, Params, undefined)
    }.

-spec to_map(license_granted_v1()) -> map().
to_map(#license_granted_v1{} = E) ->
    #{
        event_type   => <<"license_granted_v1">>,
        license_id   => E#license_granted_v1.license_id,
        grant_reason => E#license_granted_v1.grant_reason,
        granted_at   => E#license_granted_v1.granted_at,
        plugin_id    => E#license_granted_v1.plugin_id,
        plugin_name  => E#license_granted_v1.plugin_name,
        display_name => E#license_granted_v1.display_name,
        oci_image    => E#license_granted_v1.oci_image,
        version      => E#license_granted_v1.version,
        icon         => E#license_granted_v1.icon,
        group_name   => E#license_granted_v1.group_name,
        group_icon   => E#license_granted_v1.group_icon,
        plugin_type  => E#license_granted_v1.plugin_type,
        callback_module => E#license_granted_v1.callback_module,
        package_url  => E#license_granted_v1.package_url
    }.

-spec from_map(map()) -> {ok, license_granted_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_granted_v1{
                license_id   = LicenseId,
                grant_reason = hecate_api_utils:get_field(grant_reason, Map, undefined),
                granted_at   = hecate_api_utils:get_field(granted_at, Map, erlang:system_time(millisecond)),
                plugin_id    = hecate_api_utils:get_field(plugin_id, Map, undefined),
                plugin_name  = hecate_api_utils:get_field(plugin_name, Map, undefined),
                display_name = hecate_api_utils:get_field(display_name, Map, undefined),
                oci_image    = hecate_api_utils:get_field(oci_image, Map, undefined),
                version      = hecate_api_utils:get_field(version, Map, undefined),
                icon         = hecate_api_utils:get_field(icon, Map, undefined),
                group_name   = hecate_api_utils:get_field(group_name, Map, undefined),
                group_icon   = hecate_api_utils:get_field(group_icon, Map, undefined),
                plugin_type  = hecate_api_utils:get_field(plugin_type, Map, undefined),
                callback_module = hecate_api_utils:get_field(callback_module, Map, undefined),
                package_url  = hecate_api_utils:get_field(package_url, Map, undefined)
            }}
    end.

%% Accessors
-spec get_license_id(license_granted_v1()) -> binary().
get_license_id(#license_granted_v1{license_id = V}) -> V.

-spec get_grant_reason(license_granted_v1()) -> binary() | undefined.
get_grant_reason(#license_granted_v1{grant_reason = V}) -> V.

-spec get_granted_at(license_granted_v1()) -> integer().
get_granted_at(#license_granted_v1{granted_at = V}) -> V.

-spec get_plugin_id(license_granted_v1()) -> binary().
get_plugin_id(#license_granted_v1{plugin_id = V}) -> V.

-spec get_plugin_name(license_granted_v1()) -> binary() | undefined.
get_plugin_name(#license_granted_v1{plugin_name = V}) -> V.

-spec get_display_name(license_granted_v1()) -> binary() | undefined.
get_display_name(#license_granted_v1{display_name = V}) -> V.

-spec get_oci_image(license_granted_v1()) -> binary() | undefined.
get_oci_image(#license_granted_v1{oci_image = V}) -> V.

-spec get_version(license_granted_v1()) -> binary() | undefined.
get_version(#license_granted_v1{version = V}) -> V.

-spec get_icon(license_granted_v1()) -> binary() | undefined.
get_icon(#license_granted_v1{icon = V}) -> V.

-spec get_group_name(license_granted_v1()) -> binary() | undefined.
get_group_name(#license_granted_v1{group_name = V}) -> V.

-spec get_group_icon(license_granted_v1()) -> binary() | undefined.
get_group_icon(#license_granted_v1{group_icon = V}) -> V.

-spec get_plugin_type(license_granted_v1()) -> binary() | undefined.
get_plugin_type(#license_granted_v1{plugin_type = V}) -> V.

-spec get_callback_module(license_granted_v1()) -> binary() | undefined.
get_callback_module(#license_granted_v1{callback_module = V}) -> V.

-spec get_package_url(license_granted_v1()) -> binary() | undefined.
get_package_url(#license_granted_v1{package_url = V}) -> V.
