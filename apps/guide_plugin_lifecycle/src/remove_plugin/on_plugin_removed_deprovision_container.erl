%%% @doc Process Manager: On plugin removed, deprovision the container.
%%%
%%% Subscribes to plugin_removed_v1 events via evoq_event_handler.
%%% Deletes the .container Quadlet file from ~/.hecate/gitops/apps/
%%% so the local reconciler stops and removes the container.
%%% @end
-module(on_plugin_removed_deprovision_container).
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

%% Internal

do_handle(Data) ->
    PluginId = get_value(plugin_id, Data),
    case lookup_oci_image(PluginId) of
        {ok, OciImage} ->
            deprovision(PluginId, OciImage);
        {error, not_found} ->
            logger:warning("[PM] Cannot find OCI image for ~s, trying plugin_id fallback",
                           [PluginId]),
            deprovision_by_plugin_id(PluginId)
    end.

deprovision(PluginId, OciImage) ->
    DaemonName = extract_daemon_name(OciImage),
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, container_filename(DaemonName)),
    ServiceName = service_name(DaemonName),
    case shared_systemctl:reload_and_stop(ServiceName) of
        ok ->
            logger:info("[PM] Stopped service ~s", [ServiceName]);
        {error, Reason0} ->
            logger:warning("[PM] Failed to stop service ~s: ~p (continuing with file removal)",
                           [ServiceName, Reason0])
    end,
    case file:delete(FilePath) of
        ok ->
            logger:info("[PM] Deprovisioned container file ~s for plugin ~s",
                        [FilePath, PluginId]),
            _ = shared_systemctl:reload();
        {error, enoent} ->
            logger:info("[PM] Container file already absent for ~s, nothing to deprovision",
                        [PluginId]);
        {error, Reason} ->
            logger:error("[PM] Failed to delete container file ~s: ~p",
                         [FilePath, Reason])
    end.

%% @private Fallback: derive daemon name from plugin_id (legacy naming).
deprovision_by_plugin_id(PluginId) ->
    Name = case binary:split(PluginId, <<"/">>) of
        [_, N] -> N;
        [N] -> N
    end,
    LegacyDaemonName = <<"hecate-", Name/binary, "d">>,
    AppsDir = shared_paths:gitops_apps_dir(),
    FilePath = filename:join(AppsDir, <<LegacyDaemonName/binary, ".container">>),
    ServiceName = <<LegacyDaemonName/binary, ".service">>,
    case shared_systemctl:reload_and_stop(ServiceName) of
        ok -> ok;
        {error, _} -> ok
    end,
    case file:delete(FilePath) of
        ok ->
            logger:info("[PM] Deprovisioned (fallback) ~s", [FilePath]),
            _ = shared_systemctl:reload();
        _ -> ok
    end.

%% @private Look up the OCI image for a plugin from the read model.
lookup_oci_image(PluginId) ->
    case project_plugins_store:get(PluginId) of
        {ok, #{oci_image := OciImage}} -> {ok, OciImage};
        _ -> {error, not_found}
    end.

%% @private Extract the daemon name from the OCI image reference.
extract_daemon_name(OciImage) ->
    Base = strip_tag(OciImage),
    case split_last(Base, <<"/">>) of
        {_, Name} -> Name;
        nomatch -> Base
    end.

strip_tag(Image) ->
    case split_last(Image, <<":">>) of
        {Base, Tag} ->
            case binary:match(Tag, <<"/">>) of
                nomatch -> Base;
                _ -> Image
            end;
        nomatch -> Image
    end.

split_last(Bin, Sep) ->
    case binary:matches(Bin, Sep) of
        [] -> nomatch;
        Matches ->
            {Pos, Len} = lists:last(Matches),
            {binary:part(Bin, 0, Pos), binary:part(Bin, Pos + Len, byte_size(Bin) - Pos - Len)}
    end.

%% @private Build the .container filename.
container_filename(DaemonName) ->
    <<DaemonName/binary, ".container">>.

%% @private Build the systemd service name.
service_name(DaemonName) ->
    <<DaemonName/binary, ".service">>.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
