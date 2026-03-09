%%% @doc deactivate_plugin_v1 command
%%% Requests deactivation of an in-VM plugin (unloading code from the VM).
-module(deactivate_plugin_v1).

-export([new/1, from_map/1, to_map/1, validate/1]).
-export([get_plugin_id/1]).

-record(deactivate_plugin_v1, {
    plugin_id :: binary()
}).

-export_type([deactivate_plugin_v1/0]).
-opaque deactivate_plugin_v1() :: #deactivate_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, deactivate_plugin_v1()} | {error, term()}.
new(#{plugin_id := PluginId}) when is_binary(PluginId), byte_size(PluginId) > 0 ->
    {ok, #deactivate_plugin_v1{plugin_id = PluginId}};
new(_) ->
    {error, missing_plugin_id}.

-spec validate(deactivate_plugin_v1()) -> {ok, deactivate_plugin_v1()} | {error, term()}.
validate(#deactivate_plugin_v1{plugin_id = P}) when is_binary(P), byte_size(P) > 0 ->
    {ok, #deactivate_plugin_v1{plugin_id = P}};
validate(_) ->
    {error, invalid_plugin_id}.

-spec to_map(deactivate_plugin_v1()) -> map().
to_map(#deactivate_plugin_v1{plugin_id = PluginId}) ->
    #{
        <<"command_type">> => <<"deactivate_plugin">>,
        <<"plugin_id">> => PluginId
    }.

-spec from_map(map()) -> {ok, deactivate_plugin_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, missing_plugin_id};
        _ -> {ok, #deactivate_plugin_v1{plugin_id = PluginId}}
    end.

-spec get_plugin_id(deactivate_plugin_v1()) -> binary().
get_plugin_id(#deactivate_plugin_v1{plugin_id = V}) -> V.

%% Internal
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
