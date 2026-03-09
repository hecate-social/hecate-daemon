%%% @doc maybe_initiate_license handler
%%% Business logic for initiating a consumer license.
%%% Validates consumer_id, plugin_id, offering_id are non-empty binaries.
%%% Carries the full offering snapshot into the birth event.
-module(maybe_initiate_license).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).


%% @doc Handle initiate_license_v1 command (business logic only)
-spec handle(initiate_license_v1:initiate_license_v1()) ->
    {ok, [license_initiated_v1:license_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(initiate_license_v1:initiate_license_v1(), term()) ->
    {ok, [license_initiated_v1:license_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    ConsumerId = initiate_license_v1:get_consumer_id(Cmd),
    PluginId = initiate_license_v1:get_plugin_id(Cmd),
    OfferingId = initiate_license_v1:get_offering_id(Cmd),
    case validate_command(ConsumerId, PluginId, OfferingId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
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

validate_command(ConsumerId, PluginId, OfferingId) when
    is_binary(ConsumerId), byte_size(ConsumerId) > 0,
    is_binary(PluginId), byte_size(PluginId) > 0,
    is_binary(OfferingId), byte_size(OfferingId) > 0 ->
    ok;
validate_command(ConsumerId, _PluginId, _OfferingId) when
    not is_binary(ConsumerId); byte_size(ConsumerId) =:= 0 ->
    {error, invalid_consumer_id};
validate_command(_ConsumerId, PluginId, _OfferingId) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate_command(_ConsumerId, _PluginId, _OfferingId) ->
    {error, invalid_offering_id}.

create_event(Cmd) ->
    license_initiated_v1:new(#{
        license_id         => initiate_license_v1:get_license_id(Cmd),
        consumer_id        => initiate_license_v1:get_consumer_id(Cmd),
        plugin_id          => initiate_license_v1:get_plugin_id(Cmd),
        offering_id        => initiate_license_v1:get_offering_id(Cmd),
        plugin_name        => initiate_license_v1:get_plugin_name(Cmd),
        description        => initiate_license_v1:get_description(Cmd),
        icon               => initiate_license_v1:get_icon(Cmd),
        group_name         => initiate_license_v1:get_group_name(Cmd),
        github_repo        => initiate_license_v1:get_github_repo(Cmd),
        oci_image          => initiate_license_v1:get_oci_image(Cmd),
        selling_formula    => initiate_license_v1:get_selling_formula(Cmd),
        author_id          => initiate_license_v1:get_author_id(Cmd),
        license_type       => initiate_license_v1:get_license_type(Cmd),
        fee_cents          => initiate_license_v1:get_fee_cents(Cmd),
        fee_currency       => initiate_license_v1:get_fee_currency(Cmd),
        duration_days      => initiate_license_v1:get_duration_days(Cmd),
        node_limit         => initiate_license_v1:get_node_limit(Cmd),
        org                => initiate_license_v1:get_org(Cmd),
        version            => initiate_license_v1:get_version(Cmd),
        manifest_tag       => initiate_license_v1:get_manifest_tag(Cmd),
        tags               => initiate_license_v1:get_tags(Cmd),
        homepage           => initiate_license_v1:get_homepage(Cmd),
        min_daemon_version => initiate_license_v1:get_min_daemon_version(Cmd),
        publisher_identity => initiate_license_v1:get_publisher_identity(Cmd),
        manifest_url       => initiate_license_v1:get_manifest_url(Cmd),
        manifest_checksum  => initiate_license_v1:get_manifest_checksum(Cmd),
        author_signature   => initiate_license_v1:get_author_signature(Cmd),
        oci_image_verified => initiate_license_v1:get_oci_image_verified(Cmd),
        oci_image_digest   => initiate_license_v1:get_oci_image_digest(Cmd)
    }).
