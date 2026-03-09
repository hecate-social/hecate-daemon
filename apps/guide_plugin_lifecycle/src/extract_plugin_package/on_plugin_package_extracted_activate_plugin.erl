%%% @doc Process Manager: On plugin package extracted, activate the plugin.
%%%
%%% Subscribes to plugin_package_extracted_v1 events.
%%% Dispatches activate_plugin_v1 command to load the in-VM plugin code.
-module(on_plugin_package_extracted_activate_plugin).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"plugin_package_extracted_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    CallbackModule = get_value(callback_module, Data),
    case activate_plugin_v1:new(#{
        plugin_id => PluginId,
        callback_module => CallbackModule
    }) of
        {ok, Cmd} ->
            case maybe_activate_plugin:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[extract-pm] Dispatched activate_plugin for ~s", [PluginId]);
                {error, Reason} ->
                    logger:error("[extract-pm] Failed to dispatch activate_plugin for ~s: ~p",
                                 [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[extract-pm] Invalid activate_plugin command for ~s: ~p",
                         [PluginId, Reason])
    end,
    {ok, State}.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> undefined;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
