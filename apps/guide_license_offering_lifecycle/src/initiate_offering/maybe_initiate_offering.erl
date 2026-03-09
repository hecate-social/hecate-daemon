%%% @doc maybe_initiate_offering handler
%%% Business logic for initiating author-side offerings.
%%% Validates the command and dispatches via evoq.
-module(maybe_initiate_offering).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(initiate_offering_v1:initiate_offering_v1()) ->
    {ok, [offering_initiated_v1:offering_initiated_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(initiate_offering_v1:initiate_offering_v1(), term()) ->
    {ok, [offering_initiated_v1:offering_initiated_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    AuthorId = initiate_offering_v1:get_author_id(Cmd),
    PluginId = initiate_offering_v1:get_plugin_id(Cmd),
    case validate_command(AuthorId, PluginId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(initiate_offering_v1:initiate_offering_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    OfferingId = initiate_offering_v1:get_offering_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = initiate_offering,
        aggregate_type = license_offering_aggregate,
        aggregate_id = OfferingId,
        payload = initiate_offering_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => license_offering_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => license_offerings_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(AuthorId, PluginId) when
    is_binary(AuthorId), byte_size(AuthorId) > 0,
    is_binary(PluginId), byte_size(PluginId) > 0 ->
    ok;
validate_command(AuthorId, _PluginId) when
    not is_binary(AuthorId); byte_size(AuthorId) =:= 0 ->
    {error, invalid_author_id};
validate_command(_AuthorId, _PluginId) ->
    {error, invalid_plugin_id}.

create_event(Cmd) ->
    offering_initiated_v1:new(#{
        offering_id => initiate_offering_v1:get_offering_id(Cmd),
        plugin_id => initiate_offering_v1:get_plugin_id(Cmd),
        author_id => initiate_offering_v1:get_author_id(Cmd),
        plugin_name => initiate_offering_v1:get_plugin_name(Cmd),
        description => initiate_offering_v1:get_description(Cmd),
        icon => initiate_offering_v1:get_icon(Cmd),
        group_name => initiate_offering_v1:get_group_name(Cmd),
        github_repo => initiate_offering_v1:get_github_repo(Cmd),
        homepage => initiate_offering_v1:get_homepage(Cmd),
        tags => initiate_offering_v1:get_tags(Cmd),
        oci_image => initiate_offering_v1:get_oci_image(Cmd),
        org => initiate_offering_v1:get_org(Cmd),
        version => initiate_offering_v1:get_version(Cmd),
        manifest_tag => initiate_offering_v1:get_manifest_tag(Cmd),
        min_daemon_version => initiate_offering_v1:get_min_daemon_version(Cmd),
        publisher_identity => initiate_offering_v1:get_publisher_identity(Cmd),
        selling_formula => initiate_offering_v1:get_selling_formula(Cmd),
        license_type => initiate_offering_v1:get_license_type(Cmd),
        fee_cents => initiate_offering_v1:get_fee_cents(Cmd),
        fee_currency => initiate_offering_v1:get_fee_currency(Cmd),
        duration_days => initiate_offering_v1:get_duration_days(Cmd),
        node_limit => initiate_offering_v1:get_node_limit(Cmd),
        manifest_url => initiate_offering_v1:get_manifest_url(Cmd),
        manifest_checksum => initiate_offering_v1:get_manifest_checksum(Cmd),
        author_signature => initiate_offering_v1:get_author_signature(Cmd),
        oci_image_verified => initiate_offering_v1:get_oci_image_verified(Cmd),
        oci_image_digest => initiate_offering_v1:get_oci_image_digest(Cmd)
    }).
