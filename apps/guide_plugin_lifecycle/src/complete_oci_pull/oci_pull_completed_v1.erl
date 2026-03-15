%%% @doc oci_pull_completed_v1 event
%%% Emitted when an OCI image pull completes successfully.
-module(oci_pull_completed_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_plugin_id/1, get_completed_at/1]).

-record(oci_pull_completed_v1, {
    plugin_id    :: binary(),
    completed_at :: integer()
}).

-export_type([oci_pull_completed_v1/0]).
-opaque oci_pull_completed_v1() :: #oci_pull_completed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> oci_pull_completed_v1().
event_type() -> oci_pull_completed_v1.

new(#{plugin_id := PluginId}) ->
    #oci_pull_completed_v1{
        plugin_id = PluginId,
        completed_at = erlang:system_time(millisecond)
    }.

-spec to_map(oci_pull_completed_v1()) -> map().
to_map(#oci_pull_completed_v1{} = E) ->
    #{
        event_type   => <<"oci_pull_completed_v1">>,
        plugin_id    => E#oci_pull_completed_v1.plugin_id,
        completed_at => E#oci_pull_completed_v1.completed_at
    }.

-spec from_map(map()) -> {ok, oci_pull_completed_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #oci_pull_completed_v1{
                plugin_id = PluginId,
                completed_at = get_value(completed_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(oci_pull_completed_v1()) -> binary().
get_plugin_id(#oci_pull_completed_v1{plugin_id = V}) -> V.

-spec get_completed_at(oci_pull_completed_v1()) -> integer().
get_completed_at(#oci_pull_completed_v1{completed_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
