%%% @doc install_plugin_v1 command (node context)
%%% Installs a plugin on this node.
-module(install_plugin_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_plugin_id/1, get_name/1, get_display_name/1,
         get_plugin_type/1, get_oci_image/1, get_callback_module/1,
         get_package_url/1, get_installed_version/1, get_license_id/1,
         get_icon/1, get_group/1]).

-record(install_plugin_v1, {
    plugin_id         :: binary(),
    name              :: binary(),
    display_name      :: binary() | undefined,
    plugin_type       :: binary(),                %% <<"container">> | <<"in_vm">>
    oci_image         :: binary() | undefined,    %% container only
    callback_module   :: binary() | undefined,    %% in_vm only (e.g., <<"app_scribe">>)
    package_url       :: binary() | undefined,    %% in_vm only: URL to .tar.gz package
    installed_version :: binary(),
    license_id        :: binary() | undefined,
    icon              :: binary() | undefined,
    group_name        :: binary() | undefined
}).

-export_type([install_plugin_v1/0]).
-opaque install_plugin_v1() :: #install_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, install_plugin_v1()} | {error, term()}.
new(#{plugin_id := PluginId, name := Name,
      installed_version := Version} = Params) ->
    PluginType = maps:get(plugin_type, Params, <<"container">>),
    {ok, #install_plugin_v1{
        plugin_id         = PluginId,
        name              = Name,
        display_name      = maps:get(display_name, Params, undefined),
        plugin_type       = PluginType,
        oci_image         = maps:get(oci_image, Params, undefined),
        callback_module   = maps:get(callback_module, Params, undefined),
        package_url       = maps:get(package_url, Params, undefined),
        installed_version = Version,
        license_id        = maps:get(license_id, Params, undefined),
        icon              = maps:get(icon, Params, undefined),
        group_name        = maps:get(group_name, Params, undefined)
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
validate(#install_plugin_v1{installed_version = Version}) when
    not is_binary(Version); byte_size(Version) =:= 0 ->
    {error, invalid_version};
validate(#install_plugin_v1{plugin_type = PT}) when
    PT =/= <<"container">>, PT =/= <<"in_vm">> ->
    {error, invalid_plugin_type};
validate(#install_plugin_v1{plugin_type = <<"container">>, oci_image = OciImage}) when
    not is_binary(OciImage); byte_size(OciImage) =:= 0 ->
    {error, invalid_oci_image};
validate(#install_plugin_v1{plugin_type = <<"in_vm">>, callback_module = CB}) when
    not is_binary(CB); byte_size(CB) =:= 0 ->
    {error, invalid_callback_module};
validate(#install_plugin_v1{plugin_type = <<"in_vm">>, package_url = PU}) when
    not is_binary(PU); byte_size(PU) =:= 0 ->
    {error, invalid_package_url};
validate(#install_plugin_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(install_plugin_v1()) -> map().
to_map(#install_plugin_v1{} = Cmd) ->
    Base = #{
        <<"command_type">>       => <<"install_plugin">>,
        <<"plugin_id">>          => Cmd#install_plugin_v1.plugin_id,
        <<"name">>               => Cmd#install_plugin_v1.name,
        <<"plugin_type">>        => Cmd#install_plugin_v1.plugin_type,
        <<"installed_version">>  => Cmd#install_plugin_v1.installed_version
    },
    maybe_put(<<"display_name">>, Cmd#install_plugin_v1.display_name,
    maybe_put(<<"oci_image">>, Cmd#install_plugin_v1.oci_image,
    maybe_put(<<"callback_module">>, Cmd#install_plugin_v1.callback_module,
    maybe_put(<<"package_url">>, Cmd#install_plugin_v1.package_url,
    maybe_put(<<"license_id">>, Cmd#install_plugin_v1.license_id,
    maybe_put(<<"icon">>, Cmd#install_plugin_v1.icon,
    maybe_put(<<"group_name">>, Cmd#install_plugin_v1.group_name, Base))))))).

-spec from_map(map()) -> {ok, install_plugin_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    Name     = get_value(name, Map),
    Version  = get_value(installed_version, Map),
    case {PluginId, Name, Version} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #install_plugin_v1{
                plugin_id         = PluginId,
                name              = Name,
                display_name      = get_value(display_name, Map, undefined),
                plugin_type       = get_value(plugin_type, Map, <<"container">>),
                oci_image         = get_value(oci_image, Map, undefined),
                callback_module   = get_value(callback_module, Map, undefined),
                package_url       = get_value(package_url, Map, undefined),
                installed_version = Version,
                license_id        = get_value(license_id, Map, undefined),
                icon              = get_value(icon, Map, undefined),
                group_name        = get_value(group_name, Map, undefined)
            }}
    end.

%% Accessors
-spec get_plugin_id(install_plugin_v1()) -> binary().
get_plugin_id(#install_plugin_v1{plugin_id = V}) -> V.

-spec get_name(install_plugin_v1()) -> binary().
get_name(#install_plugin_v1{name = V}) -> V.

-spec get_display_name(install_plugin_v1()) -> binary() | undefined.
get_display_name(#install_plugin_v1{display_name = V}) -> V.

-spec get_plugin_type(install_plugin_v1()) -> binary().
get_plugin_type(#install_plugin_v1{plugin_type = V}) -> V.

-spec get_oci_image(install_plugin_v1()) -> binary() | undefined.
get_oci_image(#install_plugin_v1{oci_image = V}) -> V.

-spec get_callback_module(install_plugin_v1()) -> binary() | undefined.
get_callback_module(#install_plugin_v1{callback_module = V}) -> V.

-spec get_package_url(install_plugin_v1()) -> binary() | undefined.
get_package_url(#install_plugin_v1{package_url = V}) -> V.

-spec get_installed_version(install_plugin_v1()) -> binary().
get_installed_version(#install_plugin_v1{installed_version = V}) -> V.

-spec get_license_id(install_plugin_v1()) -> binary() | undefined.
get_license_id(#install_plugin_v1{license_id = V}) -> V.

-spec get_icon(install_plugin_v1()) -> binary() | undefined.
get_icon(#install_plugin_v1{icon = V}) -> V.

-spec get_group(install_plugin_v1()) -> binary() | undefined.
get_group(#install_plugin_v1{group_name = V}) -> V.

%% @private Only add key to map if value is not undefined/null.
maybe_put(_Key, undefined, Map) -> Map;
maybe_put(_Key, null, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.

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
