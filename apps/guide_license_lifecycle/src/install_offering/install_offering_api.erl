%%% @doc API handler: POST /api/appstore/install
%%%
%%% Convenience endpoint that orchestrates the install flow:
%%%   1. initiate_license (birth — full offering snapshot)
%%%   2. accept_offering_terms (lightweight consent)
%%% PMs handle grant + install asynchronously after this returns.
%%%
%%% Requires X-Hecate-User-Id header for consumer_id.
%%% Body: {plugin_id, offering_data} where offering_data is the
%%% offering snapshot from the frontend.
%%% @end
-module(install_offering_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/install", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    ConsumerId = cowboy_req:header(<<"x-hecate-user-id">>, Req0, undefined),
    case ConsumerId of
        undefined ->
            hecate_api_utils:bad_request(<<"X-Hecate-User-Id header is required">>, Req0);
        _ ->
            read_body(ConsumerId, Req0)
    end.

read_body(ConsumerId, Req0) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_install(ConsumerId, Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_install(ConsumerId, Params, Req) ->
    PluginId = hecate_api_utils:get_field(plugin_id, Params),
    OfferingData = hecate_api_utils:get_field(offering_data, Params, #{}),
    OfferingId = hecate_api_utils:get_field(offering_id, OfferingData, undefined),
    case validate(ConsumerId, PluginId, OfferingId) of
        ok -> orchestrate(ConsumerId, PluginId, OfferingId, OfferingData, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(ConsumerId, _, _) when not is_binary(ConsumerId); byte_size(ConsumerId) =:= 0 ->
    {error, <<"consumer_id must be a non-empty string">>};
validate(_, undefined, _) -> {error, <<"plugin_id is required">>};
validate(_, PluginId, _) when not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, <<"plugin_id must be a non-empty string">>};
validate(_, _, undefined) -> {error, <<"offering_id is required in offering_data">>};
validate(_, _, OfferingId) when not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, <<"offering_id must be a non-empty string">>};
validate(_, _, _) -> ok.

orchestrate(ConsumerId, PluginId, OfferingId, OfferingData, Req) ->
    %% Step 1: Initiate the license with full offering snapshot
    InitParams = build_init_params(ConsumerId, PluginId, OfferingId, OfferingData),
    case initiate_license_v1:new(InitParams) of
        {ok, InitCmd} ->
            case maybe_initiate_license:dispatch(InitCmd) of
                {ok, _Version1, _Events1} ->
                    accept_terms(InitCmd, Req);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

accept_terms(InitCmd, Req) ->
    LicenseId = initiate_license_v1:get_license_id(InitCmd),
    %% Step 2: Accept offering terms (lightweight consent)
    AcceptParams = #{license_id => LicenseId},
    case accept_offering_terms_v1:new(AcceptParams) of
        {ok, AcceptCmd} ->
            case maybe_accept_offering_terms:dispatch(AcceptCmd) of
                {ok, Version2, Events2} ->
                    hecate_api_utils:json_ok(201, #{
                        license_id => LicenseId,
                        consumer_id => initiate_license_v1:get_consumer_id(InitCmd),
                        plugin_id => initiate_license_v1:get_plugin_id(InitCmd),
                        offering_id => initiate_license_v1:get_offering_id(InitCmd),
                        version => Version2,
                        events => Events2
                    }, Req);
                {error, Reason} ->
                    hecate_api_utils:bad_request(Reason, Req)
            end;
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.

build_init_params(ConsumerId, PluginId, OfferingId, D) ->
    #{
        consumer_id        => ConsumerId,
        plugin_id          => PluginId,
        offering_id        => OfferingId,
        plugin_name        => hecate_api_utils:get_field(plugin_name, D, undefined),
        description        => hecate_api_utils:get_field(description, D, undefined),
        icon               => hecate_api_utils:get_field(icon, D, undefined),
        group_name         => hecate_api_utils:get_field(group_name, D, undefined),
        github_repo        => hecate_api_utils:get_field(github_repo, D, undefined),
        oci_image          => hecate_api_utils:get_field(oci_image, D, undefined),
        plugin_type        => hecate_api_utils:get_field(plugin_type, D, undefined),
        callback_module    => hecate_api_utils:get_field(callback_module, D, undefined),
        package_url        => hecate_api_utils:get_field(package_url, D, undefined),
        selling_formula    => hecate_api_utils:get_field(selling_formula, D, undefined),
        author_id          => hecate_api_utils:get_field(author_id, D, undefined),
        license_type       => hecate_api_utils:get_field(license_type, D, undefined),
        fee_cents          => hecate_api_utils:get_field(fee_cents, D, undefined),
        fee_currency       => hecate_api_utils:get_field(fee_currency, D, undefined),
        duration_days      => hecate_api_utils:get_field(duration_days, D, undefined),
        node_limit         => hecate_api_utils:get_field(node_limit, D, undefined),
        org                => hecate_api_utils:get_field(org, D, undefined),
        version            => hecate_api_utils:get_field(version, D, undefined),
        manifest_tag       => hecate_api_utils:get_field(manifest_tag, D, undefined),
        tags               => hecate_api_utils:get_field(tags, D, undefined),
        homepage           => hecate_api_utils:get_field(homepage, D, undefined),
        min_daemon_version => hecate_api_utils:get_field(min_daemon_version, D, undefined),
        publisher_identity => hecate_api_utils:get_field(publisher_identity, D, undefined),
        manifest_url       => hecate_api_utils:get_field(manifest_url, D, undefined),
        manifest_checksum  => hecate_api_utils:get_field(manifest_checksum, D, undefined),
        author_signature   => hecate_api_utils:get_field(author_signature, D, undefined),
        oci_image_verified => hecate_api_utils:get_field(oci_image_verified, D, undefined),
        oci_image_digest   => hecate_api_utils:get_field(oci_image_digest, D, undefined)
    }.
