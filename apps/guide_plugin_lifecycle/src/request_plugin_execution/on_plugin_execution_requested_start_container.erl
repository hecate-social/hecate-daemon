%%% @doc Process Manager: On plugin execution requested, start container.
%%%
%%% Subscribes to plugin_execution_requested_v1 events.
%%% Handles CONTAINER plugins only: starts systemd service via Quadlet.
%%%
%%% Reconciliation on restart is handled naturally by evoq event replay:
%%% evoq_store_subscription replays historical events through the handler,
%%% which will attempt to start any container that was previously running.
-module(on_plugin_execution_requested_start_container).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_execution_requested_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    case get_value(plugin_type, Data, <<"container">>) of
        <<"in_vm">> -> ok;
        _ -> start_container(get_value(plugin_id, Data), get_value(oci_image, Data))
    end,
    {ok, State}.

%% -- Container start --

start_container(PluginId, undefined) ->
    logger:error("[start-container-pm] No oci_image for ~s, cannot start container", [PluginId]);
start_container(PluginId, OciImage) when is_binary(OciImage) ->
    DaemonName = shared_podman:extract_daemon_name(OciImage),
    ServiceName = <<DaemonName/binary, ".service">>,
    case shared_systemctl:reload_and_start(ServiceName) of
        ok ->
            logger:info("[start-container-pm] Started service ~s for ~s", [ServiceName, PluginId]);
        {error, Reason} ->
            logger:error("[start-container-pm] Failed to start ~s for ~s: ~p", [ServiceName, PluginId, Reason])
    end.

%% -- Value extraction --

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> Default;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
