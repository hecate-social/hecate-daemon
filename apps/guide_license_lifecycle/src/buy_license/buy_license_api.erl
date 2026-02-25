%%% @doc API handler: POST /api/appstore/licenses/buy
%%%
%%% Acquires a license for a marketplace plugin.
%%% Lives in the buy_license desk for vertical slicing.
%%% @end
-module(buy_license_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/buy", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_buy_license(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_buy_license(Params, Req) ->
    UserId = hecate_api_utils:get_field(user_id, Params),
    PluginId = hecate_api_utils:get_field(plugin_id, Params),
    PluginName = hecate_api_utils:get_field(plugin_name, Params),
    OciImage = hecate_api_utils:get_field(oci_image, Params),

    case validate(UserId, PluginId) of
        ok -> create_license(UserId, PluginId, PluginName, OciImage, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _) -> {error, <<"user_id is required">>};
validate(UserId, _) when not is_binary(UserId); byte_size(UserId) =:= 0 ->
    {error, <<"user_id must be a non-empty string">>};
validate(_, undefined) -> {error, <<"plugin_id is required">>};
validate(_, PluginId) when not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, <<"plugin_id must be a non-empty string">>};
validate(_, _) -> ok.

create_license(UserId, PluginId, PluginName, OciImage, Req) ->
    CmdParams = #{
        user_id => UserId,
        plugin_id => PluginId,
        plugin_name => PluginName,
        oci_image => OciImage
    },
    case buy_license_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_buy_license:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                license_id => buy_license_v1:get_license_id(Cmd),
                user_id => buy_license_v1:get_user_id(Cmd),
                plugin_id => buy_license_v1:get_plugin_id(Cmd),
                plugin_name => buy_license_v1:get_plugin_name(Cmd),
                oci_image => buy_license_v1:get_oci_image(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
