%%% @doc install_plugin_v1 command (node context)
%%% Installs a plugin on this node.
-module(install_plugin_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_plugin_id/1, get_name/1, get_oci_image/1,
         get_installed_version/1, get_license_id/1]).

-record(install_plugin_v1, {
    plugin_id         :: binary(),
    name              :: binary(),
    oci_image         :: binary(),
    installed_version :: binary(),
    license_id        :: binary() | undefined
}).

-export_type([install_plugin_v1/0]).
-opaque install_plugin_v1() :: #install_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, install_plugin_v1()} | {error, term()}.
new(#{plugin_id := PluginId, name := Name,
      oci_image := OciImage, installed_version := Version} = Params) ->
    {ok, #install_plugin_v1{
        plugin_id         = PluginId,
        name              = Name,
        oci_image         = OciImage,
        installed_version = Version,
        license_id        = maps:get(license_id, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(install_plugin_v1()) -> {ok, install_plugin_v1()} | {error, term()}.
validate(#install_plugin_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#install_plugin_v1{name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_name};
validate(#install_plugin_v1{oci_image = OciImage}) when
    not is_binary(OciImage); byte_size(OciImage) =:= 0 ->
    {error, invalid_oci_image};
validate(#install_plugin_v1{installed_version = Version}) when
    not is_binary(Version); byte_size(Version) =:= 0 ->
    {error, invalid_version};
validate(#install_plugin_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(install_plugin_v1()) -> map().
to_map(#install_plugin_v1{} = Cmd) ->
    #{
        <<"command_type">>       => <<"install_plugin">>,
        <<"plugin_id">>          => Cmd#install_plugin_v1.plugin_id,
        <<"name">>               => Cmd#install_plugin_v1.name,
        <<"oci_image">>          => Cmd#install_plugin_v1.oci_image,
        <<"installed_version">>  => Cmd#install_plugin_v1.installed_version,
        <<"license_id">>         => Cmd#install_plugin_v1.license_id
    }.

-spec from_map(map()) -> {ok, install_plugin_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    Name     = get_value(name, Map),
    OciImage = get_value(oci_image, Map),
    Version  = get_value(installed_version, Map),
    LicenseId = get_value(license_id, Map, undefined),
    case {PluginId, Name, OciImage, Version} of
        {undefined, _, _, _} -> {error, missing_required_fields};
        {_, undefined, _, _} -> {error, missing_required_fields};
        {_, _, undefined, _} -> {error, missing_required_fields};
        {_, _, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #install_plugin_v1{
                plugin_id         = PluginId,
                name              = Name,
                oci_image         = OciImage,
                installed_version = Version,
                license_id        = LicenseId
            }}
    end.

%% Accessors
-spec get_plugin_id(install_plugin_v1()) -> binary().
get_plugin_id(#install_plugin_v1{plugin_id = V}) -> V.

-spec get_name(install_plugin_v1()) -> binary().
get_name(#install_plugin_v1{name = V}) -> V.

-spec get_oci_image(install_plugin_v1()) -> binary().
get_oci_image(#install_plugin_v1{oci_image = V}) -> V.

-spec get_installed_version(install_plugin_v1()) -> binary().
get_installed_version(#install_plugin_v1{installed_version = V}) -> V.

-spec get_license_id(install_plugin_v1()) -> binary() | undefined.
get_license_id(#install_plugin_v1{license_id = V}) -> V.

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
