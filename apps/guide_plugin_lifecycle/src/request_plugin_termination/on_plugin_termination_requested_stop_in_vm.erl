%%% @doc Process Manager: On plugin termination requested, unload in-VM plugin.
%%%
%%% Subscribes to plugin_termination_requested_v1 events.
%%% Handles IN-VM plugins only: unloads BEAM code via hecate_plugin_loader.
-module(on_plugin_termination_requested_stop_in_vm).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_termination_requested_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    case get_value(plugin_type, Data) of
        <<"in_vm">> ->
            unload_in_vm(get_value(plugin_id, Data));
        _ ->
            ok
    end,
    {ok, State}.

unload_in_vm(PluginId) ->
    Name = sanitize_plugin_name(PluginId),
    case hecate_plugin_loader:unload_plugin(Name) of
        ok ->
            logger:info("[stop-in-vm-pm] In-VM plugin ~s unloaded", [Name]),
            confirm_unloaded(PluginId);
        {error, not_loaded} ->
            logger:info("[stop-in-vm-pm] In-VM plugin ~s was not loaded", [Name]);
        {error, Reason} ->
            logger:error("[stop-in-vm-pm] Failed to unload in-VM plugin ~s: ~p", [Name, Reason])
    end.

confirm_unloaded(PluginId) ->
    case confirm_plugin_unloaded_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_confirm_plugin_unloaded:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[stop-in-vm-pm] Confirmed plugin ~s unloaded", [PluginId]);
                {error, Reason} ->
                    logger:error("[stop-in-vm-pm] Failed to confirm unload for ~s: ~p",
                                 [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[stop-in-vm-pm] Failed to create confirm_plugin_unloaded for ~s: ~p",
                         [PluginId, Reason])
    end.

sanitize_plugin_name(Name) when is_binary(Name) ->
    case binary:split(Name, <<"/">>) of
        [_, Short] -> Short;
        [Single] -> Single
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
