%%% @doc maybe_amend_offering handler
%%% Business logic for amending fields on an offering.
%%% Validates at least one optional field is provided.
-module(maybe_amend_offering).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(amend_offering_v1:amend_offering_v1()) ->
    {ok, [offering_amended_v1:offering_amended_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(amend_offering_v1:amend_offering_v1(), term()) ->
    {ok, [offering_amended_v1:offering_amended_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    case amend_offering_v1:validate(Cmd) of
        {ok, _} ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(amend_offering_v1:amend_offering_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    OfferingId = amend_offering_v1:get_offering_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = amend_offering,
        aggregate_type = license_offering_aggregate,
        aggregate_id = OfferingId,
        payload = amend_offering_v1:to_map(Cmd),
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

create_event(Cmd) ->
    offering_amended_v1:new(#{
        offering_id => amend_offering_v1:get_offering_id(Cmd),
        plugin_name => amend_offering_v1:get_plugin_name(Cmd),
        description => amend_offering_v1:get_description(Cmd),
        icon => amend_offering_v1:get_icon(Cmd),
        group_name => amend_offering_v1:get_group_name(Cmd),
        github_repo => amend_offering_v1:get_github_repo(Cmd),
        homepage => amend_offering_v1:get_homepage(Cmd),
        tags => amend_offering_v1:get_tags(Cmd),
        oci_image => amend_offering_v1:get_oci_image(Cmd),
        org => amend_offering_v1:get_org(Cmd),
        version => amend_offering_v1:get_version(Cmd),
        manifest_tag => amend_offering_v1:get_manifest_tag(Cmd),
        min_daemon_version => amend_offering_v1:get_min_daemon_version(Cmd),
        publisher_identity => amend_offering_v1:get_publisher_identity(Cmd),
        manifest_url => amend_offering_v1:get_manifest_url(Cmd),
        manifest_checksum => amend_offering_v1:get_manifest_checksum(Cmd),
        author_signature => amend_offering_v1:get_author_signature(Cmd),
        oci_image_verified => amend_offering_v1:get_oci_image_verified(Cmd),
        oci_image_digest => amend_offering_v1:get_oci_image_digest(Cmd),
        selling_formula => amend_offering_v1:get_selling_formula(Cmd),
        license_type => amend_offering_v1:get_license_type(Cmd),
        fee_cents => amend_offering_v1:get_fee_cents(Cmd),
        fee_currency => amend_offering_v1:get_fee_currency(Cmd),
        duration_days => amend_offering_v1:get_duration_days(Cmd),
        node_limit => amend_offering_v1:get_node_limit(Cmd)
    }).
