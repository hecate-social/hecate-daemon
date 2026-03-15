%%% @doc activate_plugin_v1 command
%%% Requests activation of an in-VM plugin (loading code, initializing, mounting routes).
-module(activate_plugin_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, to_map/1, validate/1]).
-export([command_type/0]).
-export([get_plugin_id/1, get_callback_module/1]).

-record(activate_plugin_v1, {
    plugin_id       :: binary(),
    callback_module :: binary()
}).

-export_type([activate_plugin_v1/0]).
-opaque activate_plugin_v1() :: #activate_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, activate_plugin_v1()} | {error, term()}.
command_type() -> activate_plugin_v1.

new(#{plugin_id := PluginId, callback_module := CallbackModule})
  when is_binary(PluginId), byte_size(PluginId) > 0,
       is_binary(CallbackModule), byte_size(CallbackModule) > 0 ->
    {ok, #activate_plugin_v1{plugin_id = PluginId, callback_module = CallbackModule}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(activate_plugin_v1()) -> {ok, activate_plugin_v1()} | {error, term()}.
validate(#activate_plugin_v1{plugin_id = P, callback_module = C})
  when is_binary(P), byte_size(P) > 0,
       is_binary(C), byte_size(C) > 0 ->
    {ok, #activate_plugin_v1{plugin_id = P, callback_module = C}};
validate(_) ->
    {error, invalid_command}.

-spec to_map(activate_plugin_v1()) -> map().
to_map(#activate_plugin_v1{plugin_id = PluginId, callback_module = CallbackModule}) ->
    #{
        command_type => <<"activate_plugin">>,
        plugin_id => PluginId,
        callback_module => CallbackModule
    }.

-spec from_map(map()) -> {ok, activate_plugin_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    CallbackModule = get_value(callback_module, Map),
    case {PluginId, CallbackModule} of
        {undefined, _} -> {error, missing_plugin_id};
        {_, undefined} -> {error, missing_callback_module};
        _ -> {ok, #activate_plugin_v1{plugin_id = PluginId, callback_module = CallbackModule}}
    end.

-spec get_plugin_id(activate_plugin_v1()) -> binary().
get_plugin_id(#activate_plugin_v1{plugin_id = V}) -> V.

-spec get_callback_module(activate_plugin_v1()) -> binary().
get_callback_module(#activate_plugin_v1{callback_module = V}) -> V.

%% Internal
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
