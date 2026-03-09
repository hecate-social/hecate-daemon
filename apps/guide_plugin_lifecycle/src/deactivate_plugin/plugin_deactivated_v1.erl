%%% @doc plugin_deactivated_v1 event
%%% Emitted when an in-VM plugin is deactivated (code unloaded from the VM).
-module(plugin_deactivated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_deactivated_at/1]).

-record(plugin_deactivated_v1, {
    plugin_id      :: binary(),
    deactivated_at :: integer()
}).

-export_type([plugin_deactivated_v1/0]).
-opaque plugin_deactivated_v1() :: #plugin_deactivated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_deactivated_v1().
new(#{plugin_id := PluginId}) ->
    #plugin_deactivated_v1{
        plugin_id = PluginId,
        deactivated_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_deactivated_v1()) -> map().
to_map(#plugin_deactivated_v1{} = E) ->
    #{
        event_type => <<"plugin_deactivated_v1">>,
        plugin_id  => E#plugin_deactivated_v1.plugin_id,
        deactivated_at => E#plugin_deactivated_v1.deactivated_at
    }.

-spec from_map(map()) -> {ok, plugin_deactivated_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #plugin_deactivated_v1{
                plugin_id = PluginId,
                deactivated_at = hecate_api_utils:get_field(deactivated_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(plugin_deactivated_v1()) -> binary().
get_plugin_id(#plugin_deactivated_v1{plugin_id = V}) -> V.

-spec get_deactivated_at(plugin_deactivated_v1()) -> integer().
get_deactivated_at(#plugin_deactivated_v1{deactivated_at = V}) -> V.
