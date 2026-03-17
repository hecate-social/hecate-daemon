%%% @doc Process Manager: On in-VM plugin upgraded, reload the plugin code.
%%%
%%% Subscribes to plugin_upgraded_v1 events via evoq_event_handler.
%%% Only acts when plugin_type == <<"in_vm">> and package_url is set.
%%%
%%% Idempotency: Tracks which plugin_ids have been processed this session.
%%% During catch-up replay, multiple historical plugin_upgraded_v1 events
%%% may exist for the same plugin. Only the first one triggers a reload;
%%% subsequent duplicates are skipped.
%%%
%%% Orchestration:
%%%   1. Unload current .beam files (synchronous side effect)
%%%   2. Delete stale tarball (so ensure_tarball re-downloads)
%%%   3. Dispatch extract_plugin_package_v1 (downloads new tarball + extracts)
%%%   4. Existing PM chain handles the rest:
%%%      extract -> activate -> load
%%% @end
-module(on_plugin_upgraded_reload_in_vm).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"plugin_upgraded_v1">>].

init(_Config) ->
    {ok, #{processed => #{}}}.

handle_event(_EventType, Event, _Metadata, #{processed := Processed} = State) ->
    Data = maps:get(data, Event),
    PluginId = get_value(plugin_id, Data),
    PluginType = get_value(plugin_type, Data, <<"container">>),
    PackageUrl = get_value(package_url, Data),
    case maps:is_key(PluginId, Processed) of
        true ->
            %% Already processed this plugin this session — skip.
            %% Prevents unload/reload storms from catch-up replay of
            %% multiple historical plugin_upgraded_v1 events.
            {ok, State};
        false ->
            do_handle(PluginType, PackageUrl, PluginId, Data),
            {ok, State#{processed := Processed#{PluginId => true}}}
    end.

%% Only in-VM plugins with a package_url need reload
do_handle(<<"in_vm">>, PackageUrl, PluginId, Data) when is_binary(PackageUrl), byte_size(PackageUrl) > 0 ->
    CallbackModule = get_value(callback_module, Data),
    logger:info("[PM] In-VM plugin ~s upgraded, reloading from ~s", [PluginId, PackageUrl]),
    unload_and_extract(PluginId, PackageUrl, CallbackModule);
do_handle(<<"in_vm">>, _PackageUrl, PluginId, _Data) ->
    logger:warning("[PM] In-VM plugin ~s upgraded but no package_url, skipping reload", [PluginId]);
do_handle(_, _, _, _) ->
    ok.

unload_and_extract(PluginId, PackageUrl, CallbackModule) ->
    %% Step 1: Unload current code (synchronous side effect)
    case hecate_plugin_loader:unload_plugin(PluginId) of
        ok ->
            logger:info("[PM] Unloaded in-VM plugin ~s for upgrade", [PluginId]);
        {error, UnloadErr} ->
            logger:warning("[PM] Failed to unload ~s (may not be loaded): ~p",
                           [PluginId, UnloadErr])
    end,
    %% Step 2: Delete stale tarball so ensure_tarball re-downloads
    delete_stale_tarball(PluginId, PackageUrl),
    %% Step 3: Dispatch extract_plugin_package_v1
    dispatch_extract(PluginId, PackageUrl, CallbackModule).

delete_stale_tarball(PluginId, PackageUrl) ->
    BaseDir = hecate_plugin_paths:base_dir(PluginId),
    TarFilename = filename:basename(binary_to_list(PackageUrl)),
    TarPath = filename:join(BaseDir, TarFilename),
    case file:delete(TarPath) of
        ok ->
            logger:info("[PM] Deleted stale tarball ~s", [TarPath]);
        {error, enoent} ->
            ok;
        {error, DelErr} ->
            logger:warning("[PM] Failed to delete stale tarball ~s: ~p", [TarPath, DelErr])
    end.

dispatch_extract(PluginId, PackageUrl, CallbackModule) ->
    case extract_plugin_package_v1:new(#{
        plugin_id => PluginId,
        package_url => PackageUrl,
        callback_module => CallbackModule
    }) of
        {ok, Cmd} ->
            case maybe_extract_plugin_package:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Package extraction started for upgrade of ~s", [PluginId]);
                {error, DispatchErr} ->
                    logger:error("[PM] Failed to dispatch extract for upgrade of ~s: ~p",
                                 [PluginId, DispatchErr])
            end;
        {error, CmdErr} ->
            logger:error("[PM] Failed to create extract command for upgrade of ~s: ~p",
                         [PluginId, CmdErr])
    end.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Data) -> get_value(Key, Data, undefined).

get_value(Key, Data, Default) when is_atom(Key) ->
    case maps:find(Key, Data) of
        {ok, null} -> Default;
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Data, Default)
    end.
