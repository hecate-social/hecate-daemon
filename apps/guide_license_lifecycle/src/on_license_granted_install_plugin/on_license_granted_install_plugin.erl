%%% @doc Process Manager: license_granted_v1 -> install_plugin_v1
%%%
%%% When a license is granted, dispatch install_plugin_v1 to the
%%% plugin lifecycle domain. This is a cross-domain PM.
%%%
%%% All install-relevant fields come from the event data — no read model lookup.
%%% @end
-module(on_license_granted_install_plugin).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"license_granted_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    PluginId = gf(plugin_id, Data),
    LicenseId = gf(license_id, Data),
    logger:info("[PM] License ~s granted, triggering plugin install for ~s", [LicenseId, PluginId]),
    dispatch_install(PluginId, Data),
    {ok, State}.

%% Internal

dispatch_install(PluginId, Data) ->
    TechName = tech_name_from_plugin_id(PluginId),
    InstallParams = #{
        plugin_id         => PluginId,
        name              => resolve_routing_name(gf(oci_image, Data), TechName),
        display_name      => gf(display_name, Data, gf(plugin_name, Data, TechName)),
        oci_image         => gf(oci_image, Data),
        installed_version => gf(version, Data, <<"latest">>),
        license_id        => gf(license_id, Data),
        icon              => gf(icon, Data, undefined),
        group_name        => gf(group_name, Data, undefined),
        group_icon        => gf(group_icon, Data, undefined),
        plugin_type       => gf(plugin_type, Data, <<"container">>),
        callback_module   => gf(callback_module, Data, undefined),
        package_url       => gf(package_url, Data, undefined)
    },
    case do_install(InstallParams) of
        {ok, _, _} = Ok ->
            log_result(PluginId, "install", Ok);
        {error, plugin_already_installed} ->
            %% Plugin exists — fall back to upgrade
            logger:info("[PM] Plugin ~s already installed, upgrading instead", [PluginId]),
            dispatch_upgrade(PluginId, Data);
        {error, _} = Err ->
            log_result(PluginId, "install", Err)
    end.

do_install(CmdParams) ->
    case install_plugin_v1:new(CmdParams) of
        {ok, Cmd} -> maybe_install_plugin:dispatch(Cmd);
        {error, _} = Err -> Err
    end.

dispatch_upgrade(PluginId, Data) ->
    UpgradeParams = #{
        plugin_id         => PluginId,
        oci_image         => gf(oci_image, Data),
        package_url       => gf(package_url, Data, undefined),
        plugin_type       => gf(plugin_type, Data, <<"container">>),
        installed_version => gf(version, Data, <<"latest">>),
        icon              => gf(icon, Data, undefined),
        group_name        => gf(group_name, Data, undefined),
        group_icon        => gf(group_icon, Data, undefined),
        display_name      => gf(display_name, Data, gf(plugin_name, Data, undefined)),
        description       => gf(description, Data, undefined)
    },
    case upgrade_plugin_v1:new(UpgradeParams) of
        {ok, Cmd} ->
            log_result(PluginId, "upgrade", maybe_upgrade_plugin:dispatch(Cmd));
        {error, _} = Err ->
            log_result(PluginId, "upgrade", Err)
    end.

log_result(PluginId, Action, {ok, _, _}) ->
    logger:info("[PM] Plugin ~s ~s dispatched", [PluginId, Action]);
log_result(PluginId, Action, {error, Reason}) ->
    logger:error("[PM] Failed to ~s plugin ~s: ~p", [Action, PluginId, Reason]).

resolve_routing_name(OciImage, _) when is_binary(OciImage), byte_size(OciImage) > 0 ->
    shared_podman:extract_plugin_name(OciImage);
resolve_routing_name(_, Fallback) ->
    Fallback.

%% Extract technical name from plugin_id (e.g. "hecate-apps/hecate-app-snake-duel" -> "hecate-app-snake-duel")
tech_name_from_plugin_id(PluginId) when is_binary(PluginId) ->
    case binary:split(PluginId, <<"/">>, [global]) of
        [_Org, Name] -> Name;
        _ -> PluginId
    end.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
gf(Key, Data, Default) -> hecate_api_utils:get_field(Key, Data, Default).
