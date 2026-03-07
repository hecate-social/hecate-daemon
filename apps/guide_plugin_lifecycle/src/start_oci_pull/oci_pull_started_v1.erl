%%% @doc oci_pull_started_v1 event
%%% Emitted when an OCI image pull is started for a plugin.
-module(oci_pull_started_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_oci_image/1, get_started_at/1]).

-record(oci_pull_started_v1, {
    plugin_id  :: binary(),
    oci_image  :: binary() | undefined,
    started_at :: integer()
}).

-export_type([oci_pull_started_v1/0]).
-opaque oci_pull_started_v1() :: #oci_pull_started_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> oci_pull_started_v1().
new(#{plugin_id := PluginId} = Params) ->
    #oci_pull_started_v1{
        plugin_id = PluginId,
        oci_image = maps:get(oci_image, Params, undefined),
        started_at = erlang:system_time(millisecond)
    }.

-spec to_map(oci_pull_started_v1()) -> map().
to_map(#oci_pull_started_v1{} = E) ->
    #{
        event_type => <<"oci_pull_started_v1">>,
        plugin_id  => E#oci_pull_started_v1.plugin_id,
        oci_image  => E#oci_pull_started_v1.oci_image,
        started_at => E#oci_pull_started_v1.started_at
    }.

-spec from_map(map()) -> {ok, oci_pull_started_v1()} | {error, term()}.
from_map(Map) ->
    PluginId = get_value(plugin_id, Map),
    case PluginId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #oci_pull_started_v1{
                plugin_id = PluginId,
                oci_image = get_value(oci_image, Map, undefined),
                started_at = get_value(started_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_plugin_id(oci_pull_started_v1()) -> binary().
get_plugin_id(#oci_pull_started_v1{plugin_id = V}) -> V.

-spec get_oci_image(oci_pull_started_v1()) -> binary() | undefined.
get_oci_image(#oci_pull_started_v1{oci_image = V}) -> V.

-spec get_started_at(oci_pull_started_v1()) -> integer().
get_started_at(#oci_pull_started_v1{started_at = V}) -> V.

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
