%%% @doc Process Manager: On plugin termination requested, stop container.
%%%
%%% Subscribes to plugin_termination_requested_v1 events.
%%% Handles CONTAINER plugins only: stops the systemd service.
-module(on_plugin_termination_requested_stop_container).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_termination_requested_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginType = get_value(plugin_type, Data),
    case PluginType of
        <<"in_vm">> -> ok;
        _ -> stop_container(get_value(plugin_id, Data), get_value(oci_image, Data))
    end,
    {ok, State}.

stop_container(PluginId, undefined) ->
    logger:error("[stop-container-pm] No oci_image for plugin ~s, cannot stop container", [PluginId]);
stop_container(PluginId, OciImage) ->
    DaemonName = shared_podman:extract_daemon_name(OciImage),
    ServiceName = <<DaemonName/binary, ".service">>,
    case shared_systemctl:reload_and_stop(ServiceName) of
        ok ->
            logger:info("[stop-container-pm] Stopped service ~s for plugin ~s",
                        [ServiceName, PluginId]);
        {error, Reason} ->
            logger:error("[stop-container-pm] Failed to stop service ~s: ~p",
                         [ServiceName, Reason])
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
