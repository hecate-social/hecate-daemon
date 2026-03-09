%%% @doc Process Manager: On plugin execution stopped, stop the container.
%%%
%%% Subscribes to plugin_execution_stopped_v1 events via evoq_event_handler.
%%% Calls shared_systemctl to stop the plugin's systemd service.
-module(on_plugin_execution_stopped_stop_container).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_execution_stopped_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    OciImage = get_value(oci_image, Data),
    stop_container(PluginId, OciImage),
    {ok, State}.

stop_container(PluginId, undefined) ->
    logger:error("[PM] No oci_image in event for plugin ~s, cannot stop container", [PluginId]);
stop_container(PluginId, OciImage) ->
    DaemonName = shared_podman:extract_daemon_name(OciImage),
    ServiceName = <<DaemonName/binary, ".service">>,
    case shared_systemctl:reload_and_stop(ServiceName) of
        ok ->
            logger:info("[PM] Stopped service ~s for plugin ~s",
                        [ServiceName, PluginId]);
        {error, Reason} ->
            logger:error("[PM] Failed to stop service ~s: ~p",
                         [ServiceName, Reason])
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
