%%% @doc upgrade_plugin_v1 command (node context)
%%% Upgrades an installed plugin to a new version.
-module(upgrade_plugin_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_plugin_id/1, get_oci_image/1, get_installed_version/1]).

-record(upgrade_plugin_v1, {
    plugin_id         :: binary(),
    oci_image         :: binary(),
    installed_version :: binary()
}).

-export_type([upgrade_plugin_v1/0]).
-opaque upgrade_plugin_v1() :: #upgrade_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
new(#{plugin_id := PluginId, oci_image := OciImage,
      installed_version := Version}) ->
    {ok, #upgrade_plugin_v1{
        plugin_id         = PluginId,
        oci_image         = OciImage,
        installed_version = Version
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(upgrade_plugin_v1()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
validate(#upgrade_plugin_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#upgrade_plugin_v1{oci_image = OciImage}) when
    not is_binary(OciImage); byte_size(OciImage) =:= 0 ->
    {error, invalid_oci_image};
validate(#upgrade_plugin_v1{installed_version = Version}) when
    not is_binary(Version); byte_size(Version) =:= 0 ->
    {error, invalid_version};
validate(#upgrade_plugin_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(upgrade_plugin_v1()) -> map().
to_map(#upgrade_plugin_v1{} = Cmd) ->
    #{
        <<"command_type">>      => <<"upgrade_plugin">>,
        <<"plugin_id">>         => Cmd#upgrade_plugin_v1.plugin_id,
        <<"oci_image">>         => Cmd#upgrade_plugin_v1.oci_image,
        <<"installed_version">> => Cmd#upgrade_plugin_v1.installed_version
    }.

-spec from_map(map()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    OciImage = get_value(oci_image, Map),
    Version  = get_value(installed_version, Map),
    case {PluginId, OciImage, Version} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #upgrade_plugin_v1{
                plugin_id         = PluginId,
                oci_image         = OciImage,
                installed_version = Version
            }}
    end.

%% Accessors
-spec get_plugin_id(upgrade_plugin_v1()) -> binary().
get_plugin_id(#upgrade_plugin_v1{plugin_id = V}) -> V.

-spec get_oci_image(upgrade_plugin_v1()) -> binary().
get_oci_image(#upgrade_plugin_v1{oci_image = V}) -> V.

-spec get_installed_version(upgrade_plugin_v1()) -> binary().
get_installed_version(#upgrade_plugin_v1{installed_version = V}) -> V.

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
