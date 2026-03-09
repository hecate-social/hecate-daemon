%%% @doc Process Manager: On plugin activated, load the in-VM plugin.
%%%
%%% Subscribes to plugin_activated_v1 events.
%%% Converts callback_module binary to atom, then calls
%%% hecate_plugin_loader:load_plugin/2 to load code into the VM.
%%% On success, dispatches confirm_plugin_loaded_v1.
%%% @end
-module(on_plugin_activated_load_plugin).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"plugin_activated_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    PluginName = sanitize_plugin_name(PluginId),
    CallbackModuleBin = get_value(callback_module, Data),
    do_activate(PluginId, PluginName, CallbackModuleBin, State).

do_activate(PluginId, _PluginName, undefined, State) ->
    logger:error("[activate-pm] Plugin ~s has no callback_module, cannot load", [PluginId]),
    {ok, State};
do_activate(PluginId, _PluginName, null, State) ->
    logger:error("[activate-pm] Plugin ~s has no callback_module (null), cannot load", [PluginId]),
    {ok, State};
do_activate(PluginId, PluginName, CallbackModuleBin, State) ->
    CallbackAtom = to_callback_atom(CallbackModuleBin),
    log_load_result(PluginId, PluginName, CallbackModuleBin,
                    hecate_plugin_loader:load_plugin(PluginName, CallbackAtom), State).

log_load_result(PluginId, _PluginName, CallbackModuleBin, ok, State) ->
    dispatch_confirmation(PluginId, CallbackModuleBin),
    {ok, State};
log_load_result(PluginId, _PluginName, CallbackModuleBin, {ok, _}, State) ->
    dispatch_confirmation(PluginId, CallbackModuleBin),
    {ok, State};
log_load_result(PluginId, _PluginName, CallbackModuleBin, {error, Reason}, State) ->
    logger:error("[activate-pm] Failed to load plugin ~s (~s): ~p",
                 [PluginId, CallbackModuleBin, Reason]),
    {ok, State}.

%% Internal

dispatch_confirmation(PluginId, CallbackModule) ->
    logger:info("[activate-pm] Plugin ~s loaded (~s), dispatching confirmation",
                [PluginId, CallbackModule]),
    try
        case confirm_plugin_loaded_v1:new(#{plugin_id => PluginId}) of
            {ok, Cmd} ->
                case maybe_confirm_plugin_loaded:dispatch(Cmd) of
                    {ok, Version, Events} ->
                        logger:info("[activate-pm] confirm_plugin_loaded dispatched OK for ~s (v=~p, ~p events)",
                                    [PluginId, Version, length(Events)]);
                    {error, Reason} ->
                        logger:error("[activate-pm] Failed to dispatch confirm_plugin_loaded for ~s: ~p",
                                     [PluginId, Reason])
                end;
            {error, Reason} ->
                logger:error("[activate-pm] Failed to create confirm command for ~s: ~p",
                             [PluginId, Reason])
        end
    catch
        Class:Err:Stack ->
            logger:error("[activate-pm] CRASH dispatching confirm for ~s: ~p:~p~n~p",
                         [PluginId, Class, Err, Stack])
    end.

to_callback_atom(Bin) when is_binary(Bin) ->
    try
        binary_to_existing_atom(Bin, utf8)
    catch
        error:badarg -> binary_to_atom(Bin, utf8)
    end.

%% Strip org prefix: "hecate-apps/scribe" -> <<"scribe">>
sanitize_plugin_name(Name) when is_binary(Name) ->
    case binary:split(Name, <<"/">>) of
        [_, Short] -> Short;
        [Single] -> Single
    end.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, null} -> undefined;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
