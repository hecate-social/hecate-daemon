%%% @doc confirm_container_down_v1 command
%%% Confirms that a plugin's container has stopped (socket gone).
%%% Dispatched by the plugin container watcher when the socket disappears.
-module(confirm_container_down_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_plugin_id/1]).

-record(confirm_container_down_v1, {
    plugin_id :: binary()
}).

-export_type([confirm_container_down_v1/0]).
-opaque confirm_container_down_v1() :: #confirm_container_down_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, confirm_container_down_v1()} | {error, term()}.
new(#{plugin_id := PluginId}) when is_binary(PluginId), byte_size(PluginId) > 0 ->
    {ok, #confirm_container_down_v1{plugin_id = PluginId}};
new(_) ->
    {error, missing_plugin_id}.

-spec to_map(confirm_container_down_v1()) -> map().
to_map(#confirm_container_down_v1{plugin_id = PluginId}) ->
    #{
        <<"command_type">> => <<"confirm_container_down">>,
        <<"plugin_id">> => PluginId
    }.

-spec from_map(map()) -> {ok, confirm_container_down_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, missing_plugin_id};
        _ -> {ok, #confirm_container_down_v1{plugin_id = PluginId}}
    end.

-spec get_plugin_id(confirm_container_down_v1()) -> binary().
get_plugin_id(#confirm_container_down_v1{plugin_id = V}) -> V.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
