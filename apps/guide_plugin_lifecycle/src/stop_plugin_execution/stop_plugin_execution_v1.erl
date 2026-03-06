%%% @doc stop_plugin_execution_v1 command
%%% Requests stopping execution of a running plugin.
-module(stop_plugin_execution_v1).

-export([new/1, from_map/1, to_map/1, validate/1]).
-export([get_plugin_id/1]).

-record(stop_plugin_execution_v1, {
    plugin_id :: binary()
}).

-export_type([stop_plugin_execution_v1/0]).
-opaque stop_plugin_execution_v1() :: #stop_plugin_execution_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, stop_plugin_execution_v1()} | {error, term()}.
new(#{plugin_id := PluginId}) when is_binary(PluginId), byte_size(PluginId) > 0 ->
    {ok, #stop_plugin_execution_v1{plugin_id = PluginId}};
new(_) ->
    {error, missing_plugin_id}.

-spec validate(stop_plugin_execution_v1()) -> {ok, stop_plugin_execution_v1()} | {error, term()}.
validate(#stop_plugin_execution_v1{plugin_id = P}) when is_binary(P), byte_size(P) > 0 ->
    {ok, #stop_plugin_execution_v1{plugin_id = P}};
validate(_) ->
    {error, invalid_plugin_id}.

-spec to_map(stop_plugin_execution_v1()) -> map().
to_map(#stop_plugin_execution_v1{plugin_id = PluginId}) ->
    #{
        <<"command_type">> => <<"stop_plugin_execution">>,
        <<"plugin_id">> => PluginId
    }.

-spec from_map(map()) -> {ok, stop_plugin_execution_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, missing_plugin_id};
        _ -> {ok, #stop_plugin_execution_v1{plugin_id = PluginId}}
    end.

-spec get_plugin_id(stop_plugin_execution_v1()) -> binary().
get_plugin_id(#stop_plugin_execution_v1{plugin_id = V}) -> V.

%% Internal
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
