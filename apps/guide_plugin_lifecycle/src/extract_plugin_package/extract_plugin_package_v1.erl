%%% @doc extract_plugin_package_v1 command
%%% Requests extracting a .tar.gz plugin package to ~/.hecate/plugins/{name}/.
-module(extract_plugin_package_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, to_map/1, validate/1]).
-export([command_type/0]).
-export([get_plugin_id/1, get_package_url/1, get_callback_module/1]).

-record(extract_plugin_package_v1, {
    plugin_id       :: binary(),
    package_url     :: binary(),
    callback_module :: binary() | undefined
}).

-export_type([extract_plugin_package_v1/0]).
-opaque extract_plugin_package_v1() :: #extract_plugin_package_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, extract_plugin_package_v1()} | {error, term()}.
command_type() -> extract_plugin_package_v1.

new(#{plugin_id := PluginId, package_url := PackageUrl} = Params)
  when is_binary(PluginId), byte_size(PluginId) > 0,
       is_binary(PackageUrl), byte_size(PackageUrl) > 0 ->
    {ok, #extract_plugin_package_v1{
        plugin_id = PluginId,
        package_url = PackageUrl,
        callback_module = maps:get(callback_module, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(extract_plugin_package_v1()) -> map().
to_map(#extract_plugin_package_v1{
    plugin_id = PluginId,
    package_url = PackageUrl,
    callback_module = CallbackModule
}) ->
    #{
        command_type => <<"extract_plugin_package">>,
        plugin_id => PluginId,
        package_url => PackageUrl,
        callback_module => CallbackModule
    }.

-spec from_map(map()) -> {ok, extract_plugin_package_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    PackageUrl = get_value(package_url, Map),
    case {PluginId, PackageUrl} of
        {undefined, _} -> {error, missing_plugin_id};
        {_, undefined} -> {error, missing_package_url};
        _ -> {ok, #extract_plugin_package_v1{
            plugin_id = PluginId,
            package_url = PackageUrl,
            callback_module = get_value(callback_module, Map, undefined)
        }}
    end.

-spec validate(extract_plugin_package_v1()) -> ok | {error, term()}.
validate(#extract_plugin_package_v1{plugin_id = PluginId, package_url = PackageUrl}) ->
    case {is_binary(PluginId), is_binary(PackageUrl)} of
        {true, true} when byte_size(PluginId) > 0, byte_size(PackageUrl) > 0 -> ok;
        _ -> {error, invalid_command}
    end.

-spec get_plugin_id(extract_plugin_package_v1()) -> binary().
get_plugin_id(#extract_plugin_package_v1{plugin_id = V}) -> V.

-spec get_package_url(extract_plugin_package_v1()) -> binary().
get_package_url(#extract_plugin_package_v1{package_url = V}) -> V.

-spec get_callback_module(extract_plugin_package_v1()) -> binary() | undefined.
get_callback_module(#extract_plugin_package_v1{callback_module = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
