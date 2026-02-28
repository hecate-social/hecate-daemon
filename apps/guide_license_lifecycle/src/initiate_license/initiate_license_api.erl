%%% @doc API handler: POST /api/appstore/licenses/initiate
%%%
%%% Initiates a new license for a seller.
%%% Lives in the initiate_license desk for vertical slicing.
%%% @end
-module(initiate_license_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/initiate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_initiate_license(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_initiate_license(Params, Req) ->
    SellerId = hecate_api_utils:get_field(seller_id, Params),
    PluginId = hecate_api_utils:get_field(plugin_id, Params),

    case validate(SellerId, PluginId) of
        ok -> create_license(Params, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _) -> {error, <<"seller_id is required">>};
validate(SellerId, _) when not is_binary(SellerId); byte_size(SellerId) =:= 0 ->
    {error, <<"seller_id must be a non-empty string">>};
validate(_, undefined) -> {error, <<"plugin_id is required">>};
validate(_, PluginId) when not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, <<"plugin_id must be a non-empty string">>};
validate(_, _) -> ok.

create_license(Params, Req) ->
    CmdParams = #{
        seller_id => hecate_api_utils:get_field(seller_id, Params),
        plugin_id => hecate_api_utils:get_field(plugin_id, Params),
        plugin_name => hecate_api_utils:get_field(plugin_name, Params, undefined),
        description => hecate_api_utils:get_field(description, Params, undefined),
        icon => hecate_api_utils:get_field(icon, Params, undefined),
        github_repo => hecate_api_utils:get_field(github_repo, Params, undefined),
        oci_image => hecate_api_utils:get_field(oci_image, Params, undefined),
        selling_formula => hecate_api_utils:get_field(selling_formula, Params, undefined),
        license_type => hecate_api_utils:get_field(license_type, Params, undefined),
        fee_cents => hecate_api_utils:get_field(fee_cents, Params, undefined),
        fee_currency => hecate_api_utils:get_field(fee_currency, Params, undefined),
        duration_days => hecate_api_utils:get_field(duration_days, Params, undefined),
        node_limit => hecate_api_utils:get_field(node_limit, Params, undefined),
        org => hecate_api_utils:get_field(org, Params, undefined),
        version => hecate_api_utils:get_field(version, Params, undefined),
        manifest_tag => hecate_api_utils:get_field(manifest_tag, Params, undefined),
        tags => hecate_api_utils:get_field(tags, Params, undefined),
        homepage => hecate_api_utils:get_field(homepage, Params, undefined),
        min_daemon_version => hecate_api_utils:get_field(min_daemon_version, Params, undefined),
        publisher_identity => hecate_api_utils:get_field(publisher_identity, Params, undefined)
    },
    case initiate_license_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_initiate_license:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                license_id => initiate_license_v1:get_license_id(Cmd),
                seller_id => initiate_license_v1:get_seller_id(Cmd),
                plugin_id => initiate_license_v1:get_plugin_id(Cmd),
                plugin_name => initiate_license_v1:get_plugin_name(Cmd),
                description => initiate_license_v1:get_description(Cmd),
                icon => initiate_license_v1:get_icon(Cmd),
                github_repo => initiate_license_v1:get_github_repo(Cmd),
                oci_image => initiate_license_v1:get_oci_image(Cmd),
                selling_formula => initiate_license_v1:get_selling_formula(Cmd),
                license_type => initiate_license_v1:get_license_type(Cmd),
                fee_cents => initiate_license_v1:get_fee_cents(Cmd),
                fee_currency => initiate_license_v1:get_fee_currency(Cmd),
                duration_days => initiate_license_v1:get_duration_days(Cmd),
                node_limit => initiate_license_v1:get_node_limit(Cmd),
                org => initiate_license_v1:get_org(Cmd),
                plugin_version => initiate_license_v1:get_version(Cmd),
                manifest_tag => initiate_license_v1:get_manifest_tag(Cmd),
                tags => initiate_license_v1:get_tags(Cmd),
                homepage => initiate_license_v1:get_homepage(Cmd),
                min_daemon_version => initiate_license_v1:get_min_daemon_version(Cmd),
                publisher_identity => initiate_license_v1:get_publisher_identity(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
