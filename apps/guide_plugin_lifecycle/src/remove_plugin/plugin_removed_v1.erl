%%% @doc plugin_removed_v1 event (node context)
%%% Emitted when a plugin is successfully removed from this node.
-module(plugin_removed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_removed_at/1]).

-record(plugin_removed_v1, {
    plugin_id  :: binary(),
    removed_at :: integer()
}).

-export_type([plugin_removed_v1/0]).
-opaque plugin_removed_v1() :: #plugin_removed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_removed_v1().
new(#{plugin_id := PluginId}) ->
    #plugin_removed_v1{
        plugin_id  = PluginId,
        removed_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_removed_v1()) -> map().
to_map(#plugin_removed_v1{} = E) ->
    #{
        <<"event_type">>  => <<"plugin_removed_v1">>,
        <<"plugin_id">>   => E#plugin_removed_v1.plugin_id,
        <<"removed_at">>  => E#plugin_removed_v1.removed_at
    }.

-spec from_map(map()) -> {ok, plugin_removed_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #plugin_removed_v1{
                plugin_id  = PluginId,
                removed_at = get_value(removed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_plugin_id(plugin_removed_v1()) -> binary().
get_plugin_id(#plugin_removed_v1{plugin_id = V}) -> V.

-spec get_removed_at(plugin_removed_v1()) -> integer().
get_removed_at(#plugin_removed_v1{removed_at = V}) -> V.

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
