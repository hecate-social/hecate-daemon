%%% @doc plugin_unload_confirmed_v1 event
%%% Emitted when a plugin unload has been confirmed successful.
-module(plugin_unload_confirmed_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_plugin_id/1, get_confirmed_at/1]).

-record(plugin_unload_confirmed_v1, {
    plugin_id    :: binary(),
    confirmed_at :: integer()
}).

-export_type([plugin_unload_confirmed_v1/0]).
-opaque plugin_unload_confirmed_v1() :: #plugin_unload_confirmed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_unload_confirmed_v1().
event_type() -> plugin_unload_confirmed_v1.

new(#{plugin_id := PluginId}) ->
    #plugin_unload_confirmed_v1{
        plugin_id = PluginId,
        confirmed_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_unload_confirmed_v1()) -> map().
to_map(#plugin_unload_confirmed_v1{} = E) ->
    #{
        event_type   => <<"plugin_unload_confirmed_v1">>,
        plugin_id    => E#plugin_unload_confirmed_v1.plugin_id,
        confirmed_at => E#plugin_unload_confirmed_v1.confirmed_at
    }.

-spec from_map(map()) -> {ok, plugin_unload_confirmed_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #plugin_unload_confirmed_v1{
                plugin_id = PluginId,
                confirmed_at = get_value(confirmed_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(plugin_unload_confirmed_v1()) -> binary().
get_plugin_id(#plugin_unload_confirmed_v1{plugin_id = V}) -> V.

-spec get_confirmed_at(plugin_unload_confirmed_v1()) -> integer().
get_confirmed_at(#plugin_unload_confirmed_v1{confirmed_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
