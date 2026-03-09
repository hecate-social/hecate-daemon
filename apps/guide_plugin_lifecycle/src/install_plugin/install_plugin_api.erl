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
    PluginId       = hecate_api_utils:get_field(plugin_id, Params),
    PluginType     = hecate_api_utils:get_field(plugin_type, Params, <<"container">>),
    OciImage       = hecate_api_utils:get_field(oci_image, Params),
    CallbackModule = hecate_api_utils:get_field(callback_module, Params),
    DisplayName    = coalesce(hecate_api_utils:get_field(plugin_name, Params),
                              hecate_api_utils:get_field(name, Params)),
    Version        = coalesce(hecate_api_utils:get_field(version, Params),
                              hecate_api_utils:get_field(installed_version, Params)),
    LicenseId      = hecate_api_utils:get_field(license_id, Params),
    Icon           = hecate_api_utils:get_field(icon, Params),
    GroupName      = hecate_api_utils:get_field(group_name, Params),
    Name           = resolve_name(PluginType, OciImage, DisplayName),

    case validate(PluginId, Name, PluginType, OciImage, CallbackModule, Version) of
        ok ->
            CmdParams = #{
                plugin_id         => PluginId,
                name              => Name,
                display_name      => DisplayName,
                plugin_type       => PluginType,
                oci_image         => OciImage,
                callback_module   => CallbackModule,
                installed_version => Version,
                license_id        => LicenseId,
                icon              => Icon,
                group_name        => GroupName
            },
            case install_plugin_v1:new(CmdParams) of
                {ok, Cmd} -> dispatch(Cmd, Req);
                {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

resolve_name(<<"container">>, OciImage, _DisplayName) when is_binary(OciImage) ->
    shared_podman:extract_plugin_name(OciImage);
resolve_name(_, _, DisplayName) ->
    DisplayName.

validate(undefined, _, _, _, _, _) -> {error, <<"plugin_id is required">>};
validate(_, undefined, _, _, _, _) -> {error, <<"name is required">>};
validate(_, _, _, _, _, undefined) -> {error, <<"installed_version is required">>};
validate(_, _, <<"container">>, undefined, _, _) -> {error, <<"oci_image is required for container plugins">>};
validate(_, _, <<"in_vm">>, _, undefined, _) -> {error, <<"callback_module is required for in_vm plugins">>};
validate(_, _, PT, _, _, _) when PT =/= <<"container">>, PT =/= <<"in_vm">> ->
    {error, <<"plugin_type must be 'container' or 'in_vm'">>};
validate(_, _, _, _, _, _) -> ok.

dispatch(Cmd, Req) ->
    case maybe_install_plugin:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                plugin_id         => install_plugin_v1:get_plugin_id(Cmd),
                name              => install_plugin_v1:get_name(Cmd),
                installed_version => install_plugin_v1:get_installed_version(Cmd),
                version           => Version,
                events            => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

coalesce(undefined, B) -> B;
coalesce(A, _) -> A.
