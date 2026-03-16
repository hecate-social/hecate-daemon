%%% @doc Process Manager: On plugin execution requested, load in-VM plugin.
%%%
%%% Subscribes to plugin_execution_requested_v1 events.
%%% Handles IN-VM plugins only: loads BEAM code via hecate_plugin_loader.
%%%
%%% Reconciliation on restart is handled naturally by evoq event replay:
%%% evoq_store_subscription replays historical events through the handler,
%%% which will attempt to load any in-VM plugin that was previously running.
-module(on_plugin_execution_requested_start_in_vm).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_execution_requested_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    case get_value(plugin_type, Data, <<"container">>) of
        <<"in_vm">> ->
            start_in_vm(
                get_value(plugin_id, Data),
                get_value(name, Data),
                get_value(callback_module, Data));
        _ ->
            ok
    end,
    {ok, State}.

%% -- In-VM plugin loading --

start_in_vm(PluginId, _Name, undefined) ->
    logger:error("[start-in-vm-pm] In-VM plugin ~s has no callback_module", [PluginId]);
start_in_vm(PluginId, Name, CallbackModule) when is_binary(CallbackModule) ->
    Mod = binary_to_atom(CallbackModule, utf8),
    PluginName = resolve_plugin_name(Name, PluginId),
    logger:info("[start-in-vm-pm] Loading in-VM plugin ~s (callback: ~p)", [PluginName, Mod]),
    case hecate_plugin_loader:load_plugin(PluginName, Mod) of
        ok ->
            logger:info("[start-in-vm-pm] In-VM plugin ~s loaded", [PluginName]),
            confirm_loaded(PluginId);
        {error, already_loaded} ->
            logger:info("[start-in-vm-pm] In-VM plugin ~s already loaded", [PluginName]);
        {error, Reason} ->
            logger:error("[start-in-vm-pm] Failed to load in-VM plugin ~s: ~p", [PluginName, Reason])
    end.

resolve_plugin_name(N, _Fallback) when is_binary(N), byte_size(N) > 0 -> N;
resolve_plugin_name(_, Fallback) -> Fallback.

%% -- Confirm load to aggregate --

confirm_loaded(PluginId) ->
    case confirm_plugin_loaded_v1:new(#{plugin_id => PluginId}) of
        {ok, Cmd} ->
            case maybe_confirm_plugin_loaded:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[start-in-vm-pm] Confirmed plugin ~s loaded", [PluginId]);
                {error, Reason} ->
                    logger:error("[start-in-vm-pm] Failed to confirm load for ~s: ~p",
                                 [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[start-in-vm-pm] Failed to create confirm_plugin_loaded for ~s: ~p",
                         [PluginId, Reason])
    end.

%% -- Value extraction --

get_value(Key, Map) -> get_value(Key, Map, undefined).
get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> Default;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
