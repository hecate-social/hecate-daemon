%%% @doc plugin_installed_v1 event (node context)
%%% Emitted when a plugin is successfully installed on this node.
-module(plugin_installed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_name/1, get_oci_image/1,
         get_installed_version/1, get_license_id/1, get_installed_at/1]).

-record(plugin_installed_v1, {
    plugin_id         :: binary(),
    name              :: binary(),
    oci_image         :: binary(),
    installed_version :: binary(),
    license_id        :: binary() | undefined,
    installed_at      :: integer()
}).

-export_type([plugin_installed_v1/0]).
-opaque plugin_installed_v1() :: #plugin_installed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_installed_v1().
new(#{plugin_id := PluginId, name := Name,
      oci_image := OciImage, installed_version := Version} = Params) ->
    #plugin_installed_v1{
        plugin_id         = PluginId,
        name              = Name,
        oci_image         = OciImage,
        installed_version = Version,
        license_id        = maps:get(license_id, Params, undefined),
        installed_at      = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_installed_v1()) -> map().
to_map(#plugin_installed_v1{} = E) ->
    #{
        <<"event_type">>        => <<"plugin_installed_v1">>,
        <<"plugin_id">>         => E#plugin_installed_v1.plugin_id,
        <<"name">>              => E#plugin_installed_v1.name,
        <<"oci_image">>         => E#plugin_installed_v1.oci_image,
        <<"installed_version">> => E#plugin_installed_v1.installed_version,
        <<"license_id">>        => E#plugin_installed_v1.license_id,
        <<"installed_at">>      => E#plugin_installed_v1.installed_at
    }.

-spec from_map(map()) -> {ok, plugin_installed_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    Name     = get_value(name, Map),
    OciImage = get_value(oci_image, Map),
    Version  = get_value(installed_version, Map),
    case {PluginId, Name, OciImage, Version} of
        {undefined, _, _, _} -> {error, invalid_event};
        {_, undefined, _, _} -> {error, invalid_event};
        {_, _, undefined, _} -> {error, invalid_event};
        {_, _, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #plugin_installed_v1{
                plugin_id         = PluginId,
                name              = Name,
                oci_image         = OciImage,
                installed_version = Version,
                license_id        = get_value(license_id, Map, undefined),
                installed_at      = get_value(installed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_plugin_id(plugin_installed_v1()) -> binary().
get_plugin_id(#plugin_installed_v1{plugin_id = V}) -> V.

-spec get_name(plugin_installed_v1()) -> binary().
get_name(#plugin_installed_v1{name = V}) -> V.

-spec get_oci_image(plugin_installed_v1()) -> binary().
get_oci_image(#plugin_installed_v1{oci_image = V}) -> V.

-spec get_installed_version(plugin_installed_v1()) -> binary().
get_installed_version(#plugin_installed_v1{installed_version = V}) -> V.

-spec get_license_id(plugin_installed_v1()) -> binary() | undefined.
get_license_id(#plugin_installed_v1{license_id = V}) -> V.

-spec get_installed_at(plugin_installed_v1()) -> integer().
get_installed_at(#plugin_installed_v1{installed_at = V}) -> V.

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
