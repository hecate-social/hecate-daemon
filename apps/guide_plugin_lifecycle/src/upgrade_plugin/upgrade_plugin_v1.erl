%%% @doc upgrade_plugin_v1 command (node context)
%%% Upgrades an installed plugin to a new version.
%%%
%%% Supports both plugin types:
%%%   container: requires oci_image
%%%   in_vm:     requires package_url
-module(upgrade_plugin_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_plugin_id/1, get_oci_image/1, get_installed_version/1,
         get_package_url/1, get_plugin_type/1,
         get_icon/1, get_group_name/1, get_group_icon/1,
         get_display_name/1, get_description/1]).

-record(upgrade_plugin_v1, {
    plugin_id         :: binary(),
    oci_image         :: binary() | undefined,    %% container path
    package_url       :: binary() | undefined,    %% in-VM tarball URL
    plugin_type       :: binary() | undefined,    %% <<"container">> | <<"in_vm">>
    installed_version :: binary(),
    %% Manifest metadata (from appstore offering)
    icon              :: binary() | undefined,
    group_name        :: binary() | undefined,
    group_icon        :: binary() | undefined,
    display_name      :: binary() | undefined,
    description       :: binary() | undefined
}).

-export_type([upgrade_plugin_v1/0]).
-opaque upgrade_plugin_v1() :: #upgrade_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
command_type() -> upgrade_plugin_v1.

new(#{plugin_id := PluginId, installed_version := Version} = Map) ->
    {ok, #upgrade_plugin_v1{
        plugin_id         = PluginId,
        oci_image         = maps:get(oci_image, Map, undefined),
        package_url       = maps:get(package_url, Map, undefined),
        plugin_type       = maps:get(plugin_type, Map, undefined),
        installed_version = Version,
        icon              = maps:get(icon, Map, undefined),
        group_name        = maps:get(group_name, Map, undefined),
        group_icon        = maps:get(group_icon, Map, undefined),
        display_name      = maps:get(display_name, Map, undefined),
        description       = maps:get(description, Map, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(upgrade_plugin_v1()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
validate(#upgrade_plugin_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#upgrade_plugin_v1{installed_version = Version}) when
    not is_binary(Version); byte_size(Version) =:= 0 ->
    {error, invalid_version};
%% Must have oci_image OR package_url
validate(#upgrade_plugin_v1{oci_image = undefined, package_url = undefined}) ->
    {error, missing_oci_image_or_package_url};
validate(#upgrade_plugin_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(upgrade_plugin_v1()) -> map().
to_map(#upgrade_plugin_v1{} = Cmd) ->
    #{
        command_type => <<"upgrade_plugin">>,
        plugin_id => Cmd#upgrade_plugin_v1.plugin_id,
        oci_image => Cmd#upgrade_plugin_v1.oci_image,
        package_url => Cmd#upgrade_plugin_v1.package_url,
        plugin_type => Cmd#upgrade_plugin_v1.plugin_type,
        installed_version => Cmd#upgrade_plugin_v1.installed_version,
        icon => Cmd#upgrade_plugin_v1.icon,
        group_name => Cmd#upgrade_plugin_v1.group_name,
        group_icon => Cmd#upgrade_plugin_v1.group_icon,
        display_name => Cmd#upgrade_plugin_v1.display_name,
        description => Cmd#upgrade_plugin_v1.description
    }.

-spec from_map(map()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    Version  = get_value(installed_version, Map),
    case {PluginId, Version} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            OciImage = get_value(oci_image, Map),
            PackageUrl = get_value(package_url, Map),
            case {OciImage, PackageUrl} of
                {undefined, undefined} -> {error, missing_oci_image_or_package_url};
                _ ->
                    {ok, #upgrade_plugin_v1{
                        plugin_id         = PluginId,
                        oci_image         = OciImage,
                        package_url       = PackageUrl,
                        plugin_type       = get_value(plugin_type, Map),
                        installed_version = Version,
                        icon              = get_value(icon, Map),
                        group_name        = get_value(group_name, Map),
                        group_icon        = get_value(group_icon, Map),
                        display_name      = get_value(display_name, Map),
                        description       = get_value(description, Map)
                    }}
            end
    end.

%% Accessors
-spec get_plugin_id(upgrade_plugin_v1()) -> binary().
get_plugin_id(#upgrade_plugin_v1{plugin_id = V}) -> V.

-spec get_oci_image(upgrade_plugin_v1()) -> binary() | undefined.
get_oci_image(#upgrade_plugin_v1{oci_image = V}) -> V.

-spec get_package_url(upgrade_plugin_v1()) -> binary() | undefined.
get_package_url(#upgrade_plugin_v1{package_url = V}) -> V.

-spec get_plugin_type(upgrade_plugin_v1()) -> binary() | undefined.
get_plugin_type(#upgrade_plugin_v1{plugin_type = V}) -> V.

-spec get_installed_version(upgrade_plugin_v1()) -> binary().
get_installed_version(#upgrade_plugin_v1{installed_version = V}) -> V.

-spec get_icon(upgrade_plugin_v1()) -> binary() | undefined.
get_icon(#upgrade_plugin_v1{icon = V}) -> V.

-spec get_group_name(upgrade_plugin_v1()) -> binary() | undefined.
get_group_name(#upgrade_plugin_v1{group_name = V}) -> V.

-spec get_group_icon(upgrade_plugin_v1()) -> binary() | undefined.
get_group_icon(#upgrade_plugin_v1{group_icon = V}) -> V.

-spec get_display_name(upgrade_plugin_v1()) -> binary() | undefined.
get_display_name(#upgrade_plugin_v1{display_name = V}) -> V.

-spec get_description(upgrade_plugin_v1()) -> binary() | undefined.
get_description(#upgrade_plugin_v1{description = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
