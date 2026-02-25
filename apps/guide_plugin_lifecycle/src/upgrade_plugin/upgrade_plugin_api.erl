%%% @doc API handler: POST /api/node/plugins/upgrade
%%%
%%% Upgrades an installed plugin on this node.
%%% Lives in the upgrade_plugin desk for vertical slicing.
%%% @end
-module(upgrade_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/node/plugins/upgrade", ?MODULE, []}].

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
    PluginId = hecate_api_utils:get_field(plugin_id, Params),
    OciImage = hecate_api_utils:get_field(oci_image, Params),
    Version  = hecate_api_utils:get_field(installed_version, Params),

    case validate(PluginId, OciImage, Version) of
        ok -> create_and_dispatch(PluginId, OciImage, Version, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _, _) -> {error, <<"plugin_id is required">>};
validate(_, undefined, _) -> {error, <<"oci_image is required">>};
validate(_, _, undefined) -> {error, <<"installed_version is required">>};
validate(_, _, _) -> ok.

create_and_dispatch(PluginId, OciImage, Version, Req) ->
    CmdParams = #{
        plugin_id         => PluginId,
        oci_image         => OciImage,
        installed_version => Version
    },
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
