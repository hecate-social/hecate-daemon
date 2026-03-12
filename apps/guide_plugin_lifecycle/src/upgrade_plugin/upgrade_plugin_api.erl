%%% @doc API handler: POST /api/appstore/plugins/upgrade
%%%
%%% Upgrades an installed plugin on this node.
%%% Supports both container (oci_image) and in-VM (package_url) plugins.
%%% Lives in the upgrade_plugin desk for vertical slicing.
%%% @end
-module(upgrade_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/plugins/upgrade", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_upgrade(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_upgrade(Params, Req) ->
    PluginId   = hecate_api_utils:get_field(plugin_id, Params),
    OciImage   = hecate_api_utils:get_field(oci_image, Params),
    PackageUrl = hecate_api_utils:get_field(package_url, Params),
    PluginType = hecate_api_utils:get_field(plugin_type, Params),
    Version    = hecate_api_utils:get_field(installed_version, Params),

    case validate(PluginId, OciImage, PackageUrl, Version) of
        ok ->
            CmdParams = #{
                plugin_id         => PluginId,
                oci_image         => OciImage,
                package_url       => PackageUrl,
                plugin_type       => PluginType,
                installed_version => Version,
                icon              => hecate_api_utils:get_field(icon, Params),
                group_name        => hecate_api_utils:get_field(group_name, Params),
                group_icon        => hecate_api_utils:get_field(group_icon, Params),
                display_name      => hecate_api_utils:get_field(display_name, Params),
                description       => hecate_api_utils:get_field(description, Params)
            },
            create_and_dispatch(CmdParams, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _, _, _) -> {error, <<"plugin_id is required">>};
validate(_, _, _, undefined) -> {error, <<"installed_version is required">>};
validate(_, undefined, undefined, _) -> {error, <<"oci_image or package_url is required">>};
validate(_, _, _, _) -> ok.

create_and_dispatch(CmdParams, Req) ->
    case upgrade_plugin_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_upgrade_plugin:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                plugin_id         => upgrade_plugin_v1:get_plugin_id(Cmd),
                installed_version => upgrade_plugin_v1:get_installed_version(Cmd),
                version           => Version,
                events            => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
