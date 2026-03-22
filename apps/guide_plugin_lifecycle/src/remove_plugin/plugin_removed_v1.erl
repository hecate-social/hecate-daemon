%%% @doc plugin_removed_v1 event (node context)
%%% Emitted when a plugin is successfully removed from this node.
-module(plugin_removed_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_plugin_id/1, get_oci_image/1, get_removed_at/1]).

-record(plugin_removed_v1, {
    plugin_id  :: binary(),
    oci_image  :: binary(),
    removed_at :: integer()
}).

-export_type([plugin_removed_v1/0]).
-opaque plugin_removed_v1() :: #plugin_removed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_removed_v1().
event_type() -> <<"plugin_removed_v1">>.

new(#{plugin_id := PluginId, oci_image := OciImage}) ->
    #plugin_removed_v1{
        plugin_id  = PluginId,
        oci_image  = OciImage,
        removed_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_removed_v1()) -> map().
to_map(#plugin_removed_v1{} = E) ->
    #{
        event_type  => <<"plugin_removed_v1">>,
        plugin_id   => E#plugin_removed_v1.plugin_id,
        oci_image   => E#plugin_removed_v1.oci_image,
        removed_at  => E#plugin_removed_v1.removed_at
    }.

-spec from_map(map()) -> {ok, plugin_removed_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    OciImage = hecate_api_utils:get_field(oci_image, Map),
    case {PluginId, OciImage} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #plugin_removed_v1{
                plugin_id  = PluginId,
                oci_image  = OciImage,
                removed_at = hecate_api_utils:get_field(removed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_plugin_id(plugin_removed_v1()) -> binary().
get_plugin_id(#plugin_removed_v1{plugin_id = V}) -> V.

-spec get_oci_image(plugin_removed_v1()) -> binary().
get_oci_image(#plugin_removed_v1{oci_image = V}) -> V.

-spec get_removed_at(plugin_removed_v1()) -> integer().
get_removed_at(#plugin_removed_v1{removed_at = V}) -> V.
