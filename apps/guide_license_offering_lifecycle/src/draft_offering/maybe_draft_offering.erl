%%% @doc maybe_draft_offering handler
%%% Business logic for saving an offering as a draft.
%%% Validates the command and dispatches via evoq.
-module(maybe_draft_offering).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

-spec handle(draft_offering_v1:draft_offering_v1()) ->
    {ok, [offering_drafted_v1:offering_drafted_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

-spec handle(draft_offering_v1:draft_offering_v1(), term()) ->
    {ok, [offering_drafted_v1:offering_drafted_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    OfferingId = draft_offering_v1:get_offering_id(Cmd),
    case validate_command(OfferingId) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(draft_offering_v1:draft_offering_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    OfferingId = draft_offering_v1:get_offering_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = draft_offering,
        aggregate_type = license_offering_aggregate,
        aggregate_id = OfferingId,
        payload = draft_offering_v1:to_map(Cmd),
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

validate_command(OfferingId) when
    is_binary(OfferingId), byte_size(OfferingId) > 0 ->
    ok;
validate_command(_) ->
    {error, invalid_offering_id}.

create_event(Cmd) ->
    offering_drafted_v1:new(#{
        offering_id => draft_offering_v1:get_offering_id(Cmd),
        plugin_name => draft_offering_v1:get_plugin_name(Cmd),
        description => draft_offering_v1:get_description(Cmd),
        icon => draft_offering_v1:get_icon(Cmd),
        group_name => draft_offering_v1:get_group_name(Cmd),
        github_repo => draft_offering_v1:get_github_repo(Cmd),
        homepage => draft_offering_v1:get_homepage(Cmd),
        tags => draft_offering_v1:get_tags(Cmd),
        oci_image => draft_offering_v1:get_oci_image(Cmd),
        org => draft_offering_v1:get_org(Cmd),
        version => draft_offering_v1:get_version(Cmd),
        manifest_tag => draft_offering_v1:get_manifest_tag(Cmd),
        min_daemon_version => draft_offering_v1:get_min_daemon_version(Cmd),
        publisher_identity => draft_offering_v1:get_publisher_identity(Cmd),
        selling_formula => draft_offering_v1:get_selling_formula(Cmd),
        license_type => draft_offering_v1:get_license_type(Cmd),
        fee_cents => draft_offering_v1:get_fee_cents(Cmd),
        fee_currency => draft_offering_v1:get_fee_currency(Cmd),
        duration_days => draft_offering_v1:get_duration_days(Cmd),
        node_limit => draft_offering_v1:get_node_limit(Cmd),
        manifest_url => draft_offering_v1:get_manifest_url(Cmd),
        manifest_checksum => draft_offering_v1:get_manifest_checksum(Cmd),
        author_signature => draft_offering_v1:get_author_signature(Cmd),
        oci_image_verified => draft_offering_v1:get_oci_image_verified(Cmd),
        oci_image_digest => draft_offering_v1:get_oci_image_digest(Cmd)
    }).
