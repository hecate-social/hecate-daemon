%%% @doc Process Manager: On plugin deactivated, unload the in-VM plugin code.
%%%
%%% Subscribes to plugin_deactivated_v1 events via evoq_event_handler.
%%% Calls hecate_plugin_loader:unload_plugin/1 to remove the plugin from the VM.
-module(on_plugin_deactivated_unload_plugin).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_deactivated_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    case hecate_plugin_loader:unload_plugin(PluginId) of
        ok ->
            logger:info("[PM] Unloaded in-VM plugin ~s", [PluginId]),
            maybe_confirm_unloaded(PluginId);
        {error, Reason} ->
            logger:error("[PM] Failed to unload in-VM plugin ~s: ~p",
                         [PluginId, Reason])
    end,
    {ok, State}.

maybe_confirm_unloaded(PluginId) ->
    case confirm_plugin_unloaded_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_confirm_plugin_unloaded:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("[PM] Confirmed plugin ~s unloaded", [PluginId]);
                {error, DispatchErr} ->
                    logger:error("[PM] Failed to confirm unload for ~s: ~p",
                                 [PluginId, DispatchErr])
            end;
        {error, CmdErr} ->
            logger:error("[PM] Failed to create confirm_plugin_unloaded command for ~s: ~p",
                         [PluginId, CmdErr])
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
