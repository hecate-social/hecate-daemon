%%% @doc API handler: POST /api/appstore/plugins/install
%%%
%%% Installs a plugin on this node.
%%% Lives in the install_plugin desk for vertical slicing.
%%% @end
-module(install_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/plugins/install", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_install(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_install(Params, Req) ->
    PluginId  = hecate_api_utils:get_field(plugin_id, Params),
    Name      = coalesce(hecate_api_utils:get_field(plugin_name, Params),
                         hecate_api_utils:get_field(name, Params)),
    OciImage  = hecate_api_utils:get_field(oci_image, Params),
    Version   = coalesce(hecate_api_utils:get_field(version, Params),
                         hecate_api_utils:get_field(installed_version, Params)),
    LicenseId = hecate_api_utils:get_field(license_id, Params),
    Icon      = hecate_api_utils:get_field(icon, Params),
    GroupName = hecate_api_utils:get_field(group_name, Params),

    case validate(PluginId, Name, OciImage, Version) of
        ok -> create_and_dispatch(PluginId, Name, OciImage, Version, LicenseId, Icon, GroupName, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _, _, _) -> {error, <<"plugin_id is required">>};
validate(_, undefined, _, _) -> {error, <<"name is required">>};
validate(_, _, undefined, _) -> {error, <<"oci_image is required">>};
validate(_, _, _, undefined) -> {error, <<"installed_version is required">>};
validate(_, _, _, _) -> ok.

create_and_dispatch(PluginId, Name, OciImage, Version, LicenseId, Icon, GroupName, Req) ->
    CmdParams = #{
        plugin_id         => PluginId,
        name              => Name,
        oci_image         => OciImage,
        installed_version => Version,
        license_id        => LicenseId,
        icon              => Icon,
        group_name        => GroupName
    },
    case install_plugin_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_install_plugin:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            PluginId = install_plugin_v1:get_plugin_id(Cmd),
            OciImage = install_plugin_v1:get_oci_image(Cmd),
            auto_pull(PluginId, OciImage),
            hecate_api_utils:json_ok(201, #{
                plugin_id         => PluginId,
                name              => install_plugin_v1:get_name(Cmd),
                installed_version => install_plugin_v1:get_installed_version(Cmd),
                version           => Version,
                events            => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

%% @private Auto-pull the container image after install (best-effort).
auto_pull(PluginId, OciImage) ->
    case start_container_pull_v1:new(#{plugin_id => PluginId, oci_image => OciImage}) of
        {ok, PullCmd} ->
            case maybe_start_container_pull:dispatch(PullCmd) of
                {ok, _, _} ->
                    logger:info("[install] Auto-pull started for ~s", [PluginId]);
                {error, Reason} ->
                    logger:warning("[install] Auto-pull failed for ~s: ~p", [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:warning("[install] Could not create pull command for ~s: ~p", [PluginId, Reason])
    end.

coalesce(undefined, B) -> B;
coalesce(A, _) -> A.
