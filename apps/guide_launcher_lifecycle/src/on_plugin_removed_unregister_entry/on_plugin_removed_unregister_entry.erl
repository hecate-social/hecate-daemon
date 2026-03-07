%%% @doc Process Manager: On plugin removed, unregister the launcher entry.
%%%
%%% Subscribes to plugin_removed_v1 events via evoq_event_handler.
%%% Dispatches unregister_entry_v1 to remove the plugin from the launcher.
%%% @end
-module(on_plugin_removed_unregister_entry).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_removed_v1">>].

init(_Config) ->
    {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    do_handle(Data),
    {ok, State}.

%% Internal — event handling

do_handle(Data) ->
    PluginId = get_value(plugin_id, Data),
    Name = get_value(name, Data),
    EntryId = case Name of
        undefined -> PluginId;
        _ -> Name
    end,
    CmdParams = #{entry_id => EntryId},
    case unregister_entry_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_unregister_entry:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Unregistered launcher entry ~s for plugin ~s",
                                [EntryId, PluginId]);
                {error, entry_not_found} ->
                    logger:info("[PM] Launcher entry ~s not found, skipping",
                                [EntryId]);
                {error, launcher_not_initialized} ->
                    logger:warning("[PM] Launcher not initialized, cannot unregister ~s",
                                   [EntryId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to unregister launcher entry ~s: ~p",
                                 [EntryId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Invalid unregister_entry command for ~s: ~p",
                         [PluginId, Reason])
    end.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
