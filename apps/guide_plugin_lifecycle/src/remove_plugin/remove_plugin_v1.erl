%%% @doc remove_plugin_v1 command (node context)
%%% Removes an installed plugin from this node.
-module(remove_plugin_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_plugin_id/1]).

-record(remove_plugin_v1, {
    plugin_id :: binary()
}).

-export_type([remove_plugin_v1/0]).
-opaque remove_plugin_v1() :: #remove_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, remove_plugin_v1()} | {error, term()}.
new(#{plugin_id := PluginId}) ->
    {ok, #remove_plugin_v1{
        plugin_id = PluginId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(remove_plugin_v1()) -> {ok, remove_plugin_v1()} | {error, term()}.
validate(#remove_plugin_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#remove_plugin_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(remove_plugin_v1()) -> map().
to_map(#remove_plugin_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"remove_plugin">>,
        <<"plugin_id">>    => Cmd#remove_plugin_v1.plugin_id
    }.

-spec from_map(map()) -> {ok, remove_plugin_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #remove_plugin_v1{
                plugin_id = PluginId
            }}
    end.

%% Accessors
-spec get_plugin_id(remove_plugin_v1()) -> binary().
get_plugin_id(#remove_plugin_v1{plugin_id = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> undefined
            end
    end.
