%%% @doc plugin_upgraded_v1 event (node context)
%%% Emitted when a plugin is successfully upgraded on this node.
%%%
%%% Supports both plugin types:
%%%   container: carries oci_image
%%%   in_vm:     carries package_url
-module(plugin_upgraded_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_oci_image/1,
         get_installed_version/1, get_upgraded_at/1,
         get_package_url/1, get_plugin_type/1,
         get_icon/1, get_group_name/1, get_group_icon/1,
         get_display_name/1, get_description/1]).

-record(plugin_upgraded_v1, {
    plugin_id         :: binary(),
    oci_image         :: binary() | undefined,
    package_url       :: binary() | undefined,
    plugin_type       :: binary() | undefined,
    installed_version :: binary(),
    upgraded_at       :: integer(),
    %% Manifest metadata
    icon              :: binary() | undefined,
    group_name        :: binary() | undefined,
    group_icon        :: binary() | undefined,
    display_name      :: binary() | undefined,
    description       :: binary() | undefined
}).

-export_type([plugin_upgraded_v1/0]).
-opaque plugin_upgraded_v1() :: #plugin_upgraded_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_upgraded_v1().
new(#{plugin_id := PluginId, installed_version := Version} = Map) ->
    #plugin_upgraded_v1{
        plugin_id         = PluginId,
        oci_image         = maps:get(oci_image, Map, undefined),
        package_url       = maps:get(package_url, Map, undefined),
        plugin_type       = maps:get(plugin_type, Map, undefined),
        installed_version = Version,
        upgraded_at       = erlang:system_time(millisecond),
        icon              = maps:get(icon, Map, undefined),
        group_name        = maps:get(group_name, Map, undefined),
        group_icon        = maps:get(group_icon, Map, undefined),
        display_name      = maps:get(display_name, Map, undefined),
        description       = maps:get(description, Map, undefined)
    }.

-spec to_map(plugin_upgraded_v1()) -> map().
to_map(#plugin_upgraded_v1{} = E) ->
    #{
        event_type        => <<"plugin_upgraded_v1">>,
        plugin_id         => E#plugin_upgraded_v1.plugin_id,
        oci_image         => E#plugin_upgraded_v1.oci_image,
        package_url       => E#plugin_upgraded_v1.package_url,
        plugin_type       => E#plugin_upgraded_v1.plugin_type,
        installed_version => E#plugin_upgraded_v1.installed_version,
        upgraded_at       => E#plugin_upgraded_v1.upgraded_at,
        icon              => E#plugin_upgraded_v1.icon,
        group_name        => E#plugin_upgraded_v1.group_name,
        group_icon        => E#plugin_upgraded_v1.group_icon,
        display_name      => E#plugin_upgraded_v1.display_name,
        description       => E#plugin_upgraded_v1.description
    }.

-spec from_map(map()) -> {ok, plugin_upgraded_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    Version  = get_value(installed_version, Map),
    case {PluginId, Version} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #plugin_upgraded_v1{
                plugin_id         = PluginId,
                oci_image         = get_value(oci_image, Map),
                package_url       = get_value(package_url, Map),
                plugin_type       = get_value(plugin_type, Map),
                installed_version = Version,
                upgraded_at       = get_value(upgraded_at, Map, erlang:system_time(millisecond)),
                icon              = get_value(icon, Map),
                group_name        = get_value(group_name, Map),
                group_icon        = get_value(group_icon, Map),
                display_name      = get_value(display_name, Map),
                description       = get_value(description, Map)
            }}
    end.

%% Accessors
-spec get_plugin_id(plugin_upgraded_v1()) -> binary().
get_plugin_id(#plugin_upgraded_v1{plugin_id = V}) -> V.

-spec get_oci_image(plugin_upgraded_v1()) -> binary() | undefined.
get_oci_image(#plugin_upgraded_v1{oci_image = V}) -> V.

-spec get_package_url(plugin_upgraded_v1()) -> binary() | undefined.
get_package_url(#plugin_upgraded_v1{package_url = V}) -> V.

-spec get_plugin_type(plugin_upgraded_v1()) -> binary() | undefined.
get_plugin_type(#plugin_upgraded_v1{plugin_type = V}) -> V.

-spec get_installed_version(plugin_upgraded_v1()) -> binary().
get_installed_version(#plugin_upgraded_v1{installed_version = V}) -> V.

-spec get_upgraded_at(plugin_upgraded_v1()) -> integer().
get_upgraded_at(#plugin_upgraded_v1{upgraded_at = V}) -> V.

-spec get_icon(plugin_upgraded_v1()) -> binary() | undefined.
get_icon(#plugin_upgraded_v1{icon = V}) -> V.

-spec get_group_name(plugin_upgraded_v1()) -> binary() | undefined.
get_group_name(#plugin_upgraded_v1{group_name = V}) -> V.

-spec get_group_icon(plugin_upgraded_v1()) -> binary() | undefined.
get_group_icon(#plugin_upgraded_v1{group_icon = V}) -> V.

-spec get_display_name(plugin_upgraded_v1()) -> binary() | undefined.
get_display_name(#plugin_upgraded_v1{display_name = V}) -> V.

-spec get_description(plugin_upgraded_v1()) -> binary() | undefined.
get_description(#plugin_upgraded_v1{description = V}) -> V.

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
