%%% @doc container_confirmed_down_v1 event
%%% Emitted when a plugin container is confirmed down (socket gone).
%%% Can occur after explicit stop OR after an unexpected crash.
-module(container_confirmed_down_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_confirmed_at/1]).

-record(container_confirmed_down_v1, {
    plugin_id    :: binary(),
    confirmed_at :: integer()
}).

-export_type([container_confirmed_down_v1/0]).
-opaque container_confirmed_down_v1() :: #container_confirmed_down_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> container_confirmed_down_v1().
new(#{plugin_id := PluginId}) ->
    #container_confirmed_down_v1{
        plugin_id = PluginId,
        confirmed_at = erlang:system_time(millisecond)
    }.

-spec to_map(container_confirmed_down_v1()) -> map().
to_map(#container_confirmed_down_v1{} = E) ->
    #{
        event_type   => <<"container_confirmed_down_v1">>,
        plugin_id    => E#container_confirmed_down_v1.plugin_id,
        confirmed_at => E#container_confirmed_down_v1.confirmed_at
    }.

-spec from_map(map()) -> {ok, container_confirmed_down_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #container_confirmed_down_v1{
                plugin_id = PluginId,
                confirmed_at = get_value(confirmed_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(container_confirmed_down_v1()) -> binary().
get_plugin_id(#container_confirmed_down_v1{plugin_id = V}) -> V.

-spec get_confirmed_at(container_confirmed_down_v1()) -> integer().
get_confirmed_at(#container_confirmed_down_v1{confirmed_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
