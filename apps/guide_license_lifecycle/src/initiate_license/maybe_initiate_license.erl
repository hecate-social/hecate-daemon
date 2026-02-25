%%% @doc maybe_initiate_license handler
%%% Business logic for initiating seller-side licenses.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_license).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(initiate_license_v1:initiate_license_v1()) ->
    {ok, [license_initiated_v1:license_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(initiate_license_v1:initiate_license_v1(), term()) ->
    {ok, [license_initiated_v1:license_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    SellerId = initiate_license_v1:get_seller_id(Cmd),
    PluginId = initiate_license_v1:get_plugin_id(Cmd),
    case validate_command(SellerId, PluginId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(initiate_license_v1:initiate_license_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = initiate_license_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initiate_license,
        aggregate_type = license_aggregate,
        aggregate_id = LicenseId,
        payload = initiate_license_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => license_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => licenses_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(SellerId, PluginId) when
    is_binary(SellerId), byte_size(SellerId) > 0,
    is_binary(PluginId), byte_size(PluginId) > 0 ->
    ok;
validate_command(SellerId, _PluginId) when
    not is_binary(SellerId); byte_size(SellerId) =:= 0 ->
    {error, invalid_seller_id};
validate_command(_SellerId, _PluginId) ->
    {error, invalid_plugin_id}.

create_event(Cmd) ->
    license_initiated_v1:new(#{
        license_id => initiate_license_v1:get_license_id(Cmd),
        plugin_id => initiate_license_v1:get_plugin_id(Cmd),
        plugin_name => initiate_license_v1:get_plugin_name(Cmd),
        description => initiate_license_v1:get_description(Cmd),
        icon => initiate_license_v1:get_icon(Cmd),
        github_repo => initiate_license_v1:get_github_repo(Cmd),
        oci_image => initiate_license_v1:get_oci_image(Cmd),
        selling_formula => initiate_license_v1:get_selling_formula(Cmd),
        seller_id => initiate_license_v1:get_seller_id(Cmd),
        org => initiate_license_v1:get_org(Cmd),
        version => initiate_license_v1:get_version(Cmd),
        manifest_tag => initiate_license_v1:get_manifest_tag(Cmd),
        tags => initiate_license_v1:get_tags(Cmd),
        homepage => initiate_license_v1:get_homepage(Cmd),
        min_daemon_version => initiate_license_v1:get_min_daemon_version(Cmd),
        publisher_identity => initiate_license_v1:get_publisher_identity(Cmd)
    }).
