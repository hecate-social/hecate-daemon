%%% @doc plugin_package_extracted_v1 event
%%% Emitted when a .tar.gz plugin package has been extracted to disk.
-module(plugin_package_extracted_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_plugin_id/1, get_callback_module/1, get_extracted_at/1]).

-record(plugin_package_extracted_v1, {
    plugin_id       :: binary(),
    callback_module :: binary() | undefined,
    extracted_at    :: integer()
}).

-export_type([plugin_package_extracted_v1/0]).
-opaque plugin_package_extracted_v1() :: #plugin_package_extracted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_package_extracted_v1().
event_type() -> <<"plugin_package_extracted_v1">>.

new(#{plugin_id := PluginId} = Params) ->
    #plugin_package_extracted_v1{
        plugin_id = PluginId,
        callback_module = maps:get(callback_module, Params, undefined),
        extracted_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_package_extracted_v1()) -> map().
to_map(#plugin_package_extracted_v1{} = E) ->
    #{
        event_type => <<"plugin_package_extracted_v1">>,
        plugin_id  => E#plugin_package_extracted_v1.plugin_id,
        callback_module => E#plugin_package_extracted_v1.callback_module,
        extracted_at => E#plugin_package_extracted_v1.extracted_at
    }.

-spec from_map(map()) -> {ok, plugin_package_extracted_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #plugin_package_extracted_v1{
                plugin_id = PluginId,
                callback_module = hecate_api_utils:get_field(callback_module, Map, undefined),
                extracted_at = hecate_api_utils:get_field(extracted_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(plugin_package_extracted_v1()) -> binary().
get_plugin_id(#plugin_package_extracted_v1{plugin_id = V}) -> V.

-spec get_callback_module(plugin_package_extracted_v1()) -> binary() | undefined.
get_callback_module(#plugin_package_extracted_v1{callback_module = V}) -> V.

-spec get_extracted_at(plugin_package_extracted_v1()) -> integer().
get_extracted_at(#plugin_package_extracted_v1{extracted_at = V}) -> V.
