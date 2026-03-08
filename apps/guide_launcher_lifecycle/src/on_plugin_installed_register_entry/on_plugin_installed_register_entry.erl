%%% @doc Process Manager: On plugin installed, register a launcher entry.
%%%
%%% Subscribes to plugin_installed_v1 events via evoq_event_handler.
%%% Dispatches register_entry_v1 to add the plugin to the launcher
%%% under the "APPS" group.
%%% @end
-module(on_plugin_installed_register_entry).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_installed_v1">>].

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
    EntryId = Name,
    DisplayName = Name,
    Icon = coalesce(get_value(icon, Data), <<"\xF0\x9F\x94\x8C">>),
    GroupName = coalesce(get_value(group_name, Data), <<"APPS">>),
    CmdParams = #{
        entry_id     => EntryId,
        display_name => DisplayName,
        icon         => Icon,
        group_name   => GroupName
    },
    case register_entry_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_register_entry:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Registered launcher entry ~s for plugin ~s",
                                [EntryId, PluginId]);
                {error, entry_already_registered} ->
                    logger:info("[PM] Launcher entry ~s already exists, skipping",
                                [EntryId]);
                {error, launcher_not_initialized} ->
                    logger:warning("[PM] Launcher not initialized, cannot register ~s",
                                   [EntryId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to register launcher entry ~s: ~p",
                                 [EntryId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Invalid register_entry command for ~s: ~p",
                         [PluginId, Reason])
    end.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

coalesce(undefined, Default) -> Default;
coalesce(null, Default) -> Default;
coalesce(<<"undefined">>, Default) -> Default;
coalesce(<<"null">>, Default) -> Default;
coalesce(<<>>, Default) -> Default;
coalesce(Value, _Default) -> Value.
