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
    LicenseId = hecate_api_utils:get_field(license_id, Data),
    PluginId = hecate_api_utils:get_field(plugin_id, Data),
    OciImage = hecate_api_utils:get_field(oci_image, Data),
    logger:info("[PM] License ~s granted, triggering plugin install for ~s", [LicenseId, PluginId]),
    PluginName = hecate_api_utils:get_field(plugin_name, Data, PluginId),
    RoutingName = shared_podman:extract_plugin_name(OciImage),
    CmdParams = #{
        plugin_id         => PluginId,
        name              => RoutingName,
        display_name      => PluginName,
        oci_image         => OciImage,
        installed_version => hecate_api_utils:get_field(version, Data, <<"latest">>),
        license_id        => LicenseId,
        icon              => hecate_api_utils:get_field(icon, Data, undefined),
        group_name        => hecate_api_utils:get_field(group_name, Data, undefined)
    },
    case install_plugin_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_install_plugin:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Plugin ~s install dispatched", [PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to install plugin ~s: ~p", [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Failed to create install command for ~s: ~p", [PluginId, Reason])
    end,
    {ok, State}.
