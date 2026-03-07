%%% @doc complete_container_pull_v1 command
%%% Confirms that an OCI image pull has completed successfully.
%%% Dispatched by the pull PM when podman pull finishes.
-module(complete_container_pull_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_plugin_id/1]).

-record(complete_container_pull_v1, {
    plugin_id :: binary()
}).

-export_type([complete_container_pull_v1/0]).
-opaque complete_container_pull_v1() :: #complete_container_pull_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, complete_container_pull_v1()} | {error, term()}.
new(#{plugin_id := PluginId}) when is_binary(PluginId), byte_size(PluginId) > 0 ->
    {ok, #complete_container_pull_v1{plugin_id = PluginId}};
new(_) ->
    {error, missing_plugin_id}.

-spec to_map(complete_container_pull_v1()) -> map().
to_map(#complete_container_pull_v1{plugin_id = PluginId}) ->
    #{
        <<"command_type">> => <<"complete_container_pull">>,
        <<"plugin_id">> => PluginId
    }.

-spec from_map(map()) -> {ok, complete_container_pull_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, missing_plugin_id};
        _ -> {ok, #complete_container_pull_v1{plugin_id = PluginId}}
    end.

-spec get_plugin_id(complete_container_pull_v1()) -> binary().
get_plugin_id(#complete_container_pull_v1{plugin_id = V}) -> V.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
