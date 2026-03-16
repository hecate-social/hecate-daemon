%%% @doc request_plugin_execution_v1 command
%%% Requests starting execution of an installed plugin.
-module(request_plugin_execution_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, to_map/1, validate/1]).
-export([command_type/0]).
-export([get_plugin_id/1]).

-record(request_plugin_execution_v1, {
    plugin_id :: binary()
}).

-export_type([request_plugin_execution_v1/0]).
-opaque request_plugin_execution_v1() :: #request_plugin_execution_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, request_plugin_execution_v1()} | {error, term()}.
command_type() -> request_plugin_execution_v1.

new(#{plugin_id := PluginId}) when is_binary(PluginId), byte_size(PluginId) > 0 ->
    {ok, #request_plugin_execution_v1{plugin_id = PluginId}};
new(_) ->
    {error, missing_plugin_id}.

-spec validate(request_plugin_execution_v1()) -> {ok, request_plugin_execution_v1()} | {error, term()}.
validate(#request_plugin_execution_v1{plugin_id = P}) when is_binary(P), byte_size(P) > 0 ->
    {ok, #request_plugin_execution_v1{plugin_id = P}};
validate(_) ->
    {error, invalid_plugin_id}.

-spec to_map(request_plugin_execution_v1()) -> map().
to_map(#request_plugin_execution_v1{plugin_id = PluginId}) ->
    #{
        command_type => <<"request_plugin_execution">>,
        plugin_id => PluginId
    }.

-spec from_map(map()) -> {ok, request_plugin_execution_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, missing_plugin_id};
        _ -> {ok, #request_plugin_execution_v1{plugin_id = PluginId}}
    end.

-spec get_plugin_id(request_plugin_execution_v1()) -> binary().
get_plugin_id(#request_plugin_execution_v1{plugin_id = V}) -> V.

%% Internal
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
