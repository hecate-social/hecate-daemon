%%% @doc plugin_termination_requested_v1 event
%%% Emitted when plugin termination is requested on this node.
-module(plugin_termination_requested_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_plugin_id/1, get_oci_image/1, get_plugin_type/1, get_requested_at/1]).

-record(plugin_termination_requested_v1, {
    plugin_id   :: binary(),
    oci_image   :: binary() | undefined,
    plugin_type :: binary() | undefined,
    requested_at :: integer()
}).

-export_type([plugin_termination_requested_v1/0]).
-opaque plugin_termination_requested_v1() :: #plugin_termination_requested_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_termination_requested_v1().
event_type() -> plugin_termination_requested_v1.

new(Data) ->
    #plugin_termination_requested_v1{
        plugin_id   = maps:get(plugin_id, Data),
        oci_image   = maps:get(oci_image, Data, undefined),
        plugin_type = maps:get(plugin_type, Data, undefined),
        requested_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_termination_requested_v1()) -> map().
to_map(#plugin_termination_requested_v1{} = E) ->
    #{
        event_type   => <<"plugin_termination_requested_v1">>,
        plugin_id    => E#plugin_termination_requested_v1.plugin_id,
        oci_image    => E#plugin_termination_requested_v1.oci_image,
        plugin_type  => E#plugin_termination_requested_v1.plugin_type,
        requested_at => E#plugin_termination_requested_v1.requested_at
    }.

-spec from_map(map()) -> {ok, plugin_termination_requested_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #plugin_termination_requested_v1{
                plugin_id    = PluginId,
                oci_image    = hecate_api_utils:get_field(oci_image, Map),
                plugin_type  = hecate_api_utils:get_field(plugin_type, Map),
                requested_at = hecate_api_utils:get_field(requested_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(plugin_termination_requested_v1()) -> binary().
get_plugin_id(#plugin_termination_requested_v1{plugin_id = V}) -> V.

-spec get_oci_image(plugin_termination_requested_v1()) -> binary() | undefined.
get_oci_image(#plugin_termination_requested_v1{oci_image = V}) -> V.

-spec get_plugin_type(plugin_termination_requested_v1()) -> binary() | undefined.
get_plugin_type(#plugin_termination_requested_v1{plugin_type = V}) -> V.

-spec get_requested_at(plugin_termination_requested_v1()) -> integer().
get_requested_at(#plugin_termination_requested_v1{requested_at = V}) -> V.
