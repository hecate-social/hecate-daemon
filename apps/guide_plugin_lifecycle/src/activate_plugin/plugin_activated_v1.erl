%%% @doc plugin_activated_v1 event
%%% Emitted when an in-VM plugin is activated (code loaded, initialized, routes mounted).
-module(plugin_activated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_callback_module/1, get_activated_at/1]).

-record(plugin_activated_v1, {
    plugin_id       :: binary(),
    callback_module :: binary(),
    activated_at    :: integer()
}).

-export_type([plugin_activated_v1/0]).
-opaque plugin_activated_v1() :: #plugin_activated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_activated_v1().
new(#{plugin_id := PluginId, callback_module := CallbackModule}) ->
    #plugin_activated_v1{
        plugin_id = PluginId,
        callback_module = CallbackModule,
        activated_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_activated_v1()) -> map().
to_map(#plugin_activated_v1{} = E) ->
    #{
        event_type      => <<"plugin_activated_v1">>,
        plugin_id       => E#plugin_activated_v1.plugin_id,
        callback_module => E#plugin_activated_v1.callback_module,
        activated_at    => E#plugin_activated_v1.activated_at
    }.

-spec from_map(map()) -> {ok, plugin_activated_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    CallbackModule = hecate_api_utils:get_field(callback_module, Map),
    case {PluginId, CallbackModule} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #plugin_activated_v1{
                plugin_id = PluginId,
                callback_module = CallbackModule,
                activated_at = hecate_api_utils:get_field(activated_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(plugin_activated_v1()) -> binary().
get_plugin_id(#plugin_activated_v1{plugin_id = V}) -> V.

-spec get_callback_module(plugin_activated_v1()) -> binary().
get_callback_module(#plugin_activated_v1{callback_module = V}) -> V.

-spec get_activated_at(plugin_activated_v1()) -> integer().
get_activated_at(#plugin_activated_v1{activated_at = V}) -> V.
