%%% @doc start_oci_pull_v1 command
%%% Requests starting an OCI image pull for an installed plugin.
-module(start_oci_pull_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, to_map/1]).
-export([command_type/0]).
-export([get_plugin_id/1, get_oci_image/1]).

-record(start_oci_pull_v1, {
    plugin_id :: binary(),
    oci_image :: binary() | undefined
}).

-export_type([start_oci_pull_v1/0]).
-opaque start_oci_pull_v1() :: #start_oci_pull_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, start_oci_pull_v1()} | {error, term()}.
command_type() -> start_oci_pull_v1.

new(#{plugin_id := PluginId} = Params) when is_binary(PluginId), byte_size(PluginId) > 0 ->
    {ok, #start_oci_pull_v1{
        plugin_id = PluginId,
        oci_image = maps:get(oci_image, Params, undefined)
    }};
new(_) ->
    {error, missing_plugin_id}.

-spec to_map(start_oci_pull_v1()) -> map().
to_map(#start_oci_pull_v1{plugin_id = PluginId, oci_image = OciImage}) ->
    #{
        command_type => <<"start_oci_pull">>,
        plugin_id => PluginId,
        oci_image => OciImage
    }.

-spec from_map(map()) -> {ok, start_oci_pull_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, missing_plugin_id};
        _ -> {ok, #start_oci_pull_v1{
            plugin_id = PluginId,
            oci_image = get_value(oci_image, Map, undefined)
        }}
    end.

-spec get_plugin_id(start_oci_pull_v1()) -> binary().
get_plugin_id(#start_oci_pull_v1{plugin_id = V}) -> V.

-spec get_oci_image(start_oci_pull_v1()) -> binary() | undefined.
get_oci_image(#start_oci_pull_v1{oci_image = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
