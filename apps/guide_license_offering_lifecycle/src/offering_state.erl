%%% @doc Offering state module — implements evoq_state behaviour.
%%%
%%% Owns the offering_state record, initial state creation, event folding,
%%% and serialization. Extracted from license_offering_aggregate to separate
%%% state concerns from command validation.
%%% @end
-module(offering_state).

-behaviour(evoq_state).

-include("offering_status.hrl").
-include("offering_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #offering_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #offering_state{status = 0}.

-spec apply_event(state(), map()) -> state().

apply_event(S, #{event_type := <<"offering_initiated_v1">>} = E)  -> apply_initiated(E, S);
apply_event(S, #{event_type := <<"offering_drafted_v1">>} = E)    -> apply_drafted(E, S);
apply_event(S, #{event_type := <<"offering_announced_v1">>} = E)  -> apply_announced(E, S);
apply_event(S, #{event_type := <<"offering_published_v1">>} = E)  -> apply_published(E, S);
apply_event(S, #{event_type := <<"offering_retracted_v1">>} = E)  -> apply_retracted(E, S);
apply_event(S, #{event_type := <<"offering_amended_v1">>} = E)    -> apply_amended(E, S);
apply_event(S, #{event_type := <<"offering_archived_v1">>} = E)   -> apply_archived(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#offering_state{} = S) ->
    #{
        offering_id => S#offering_state.offering_id,
        plugin_id => S#offering_state.plugin_id,
        author_id => S#offering_state.author_id,
        status => S#offering_state.status,
        plugin_name => S#offering_state.plugin_name,
        display_name => S#offering_state.display_name,
        description => S#offering_state.description,
        icon => S#offering_state.icon,
        group_name => S#offering_state.group_name,
        group_icon => S#offering_state.group_icon,
        github_repo => S#offering_state.github_repo,
        homepage => S#offering_state.homepage,
        tags => S#offering_state.tags,
        oci_image => S#offering_state.oci_image,
        package_url => S#offering_state.package_url,
        plugin_type => S#offering_state.plugin_type,
        callback_module => S#offering_state.callback_module,
        org => S#offering_state.org,
        version => S#offering_state.version,
        manifest_tag => S#offering_state.manifest_tag,
        min_daemon_version => S#offering_state.min_daemon_version,
        publisher_identity => S#offering_state.publisher_identity,
        selling_formula => S#offering_state.selling_formula,
        license_type => S#offering_state.license_type,
        fee_cents => S#offering_state.fee_cents,
        fee_currency => S#offering_state.fee_currency,
        duration_days => S#offering_state.duration_days,
        node_limit => S#offering_state.node_limit,
        manifest_url => S#offering_state.manifest_url,
        manifest_checksum => S#offering_state.manifest_checksum,
        author_signature => S#offering_state.author_signature,
        oci_image_verified => S#offering_state.oci_image_verified,
        oci_image_digest => S#offering_state.oci_image_digest,
        initiated_at => S#offering_state.initiated_at,
        announced_at => S#offering_state.announced_at,
        published_at => S#offering_state.published_at,
        retracted_at => S#offering_state.retracted_at,
        archived_at => S#offering_state.archived_at
    }.

%% --- Apply helpers ---

apply_initiated(E, State) ->
    State#offering_state{
        offering_id = hecate_api_utils:get_field(offering_id, E),
        plugin_id = hecate_api_utils:get_field(plugin_id, E),
        author_id = hecate_api_utils:get_field(author_id, E),
        plugin_name = hecate_api_utils:get_field(plugin_name, E),
        display_name = hecate_api_utils:get_field(display_name, E),
        description = hecate_api_utils:get_field(description, E),
        icon = hecate_api_utils:get_field(icon, E),
        group_name = hecate_api_utils:get_field(group_name, E),
        group_icon = hecate_api_utils:get_field(group_icon, E),
        github_repo = hecate_api_utils:get_field(github_repo, E),
        homepage = hecate_api_utils:get_field(homepage, E),
        tags = hecate_api_utils:get_field(tags, E),
        oci_image = hecate_api_utils:get_field(oci_image, E),
        package_url = hecate_api_utils:get_field(package_url, E),
        plugin_type = hecate_api_utils:get_field(plugin_type, E),
        callback_module = hecate_api_utils:get_field(callback_module, E),
        org = hecate_api_utils:get_field(org, E),
        version = hecate_api_utils:get_field(version, E),
        manifest_tag = hecate_api_utils:get_field(manifest_tag, E),
        min_daemon_version = hecate_api_utils:get_field(min_daemon_version, E),
        publisher_identity = hecate_api_utils:get_field(publisher_identity, E),
        selling_formula = hecate_api_utils:get_field(selling_formula, E),
        license_type = hecate_api_utils:get_field(license_type, E),
        fee_cents = hecate_api_utils:get_field(fee_cents, E),
        fee_currency = hecate_api_utils:get_field(fee_currency, E),
        duration_days = hecate_api_utils:get_field(duration_days, E),
        node_limit = hecate_api_utils:get_field(node_limit, E),
        manifest_url = hecate_api_utils:get_field(manifest_url, E),
        manifest_checksum = hecate_api_utils:get_field(manifest_checksum, E),
        author_signature = hecate_api_utils:get_field(author_signature, E),
        oci_image_verified = hecate_api_utils:get_field(oci_image_verified, E),
        oci_image_digest = hecate_api_utils:get_field(oci_image_digest, E),
        status = evoq_bit_flags:set(0, ?OFF_INITIATED),
        initiated_at = hecate_api_utils:get_field(initiated_at, E)
    }.

apply_drafted(E, State) ->
    Fields = [
        plugin_name, display_name, description, icon, group_name, group_icon, github_repo, homepage, tags,
        oci_image, package_url, plugin_type, callback_module,
        org, version, manifest_tag, min_daemon_version, publisher_identity,
        selling_formula, license_type, fee_cents, fee_currency,
        duration_days, node_limit,
        manifest_url, manifest_checksum, author_signature,
        oci_image_verified, oci_image_digest
    ],
    lists:foldl(
        fun(Field, S) -> maybe_set(Field, hecate_api_utils:get_field(Field, E), S) end,
        State,
        Fields
    ).

apply_announced(E, #offering_state{status = Status} = State) ->
    State#offering_state{
        status = evoq_bit_flags:set(Status, ?OFF_ANNOUNCED),
        announced_at = hecate_api_utils:get_field(announced_at, E)
    }.

apply_published(E, #offering_state{status = Status} = State) ->
    State#offering_state{
        status = evoq_bit_flags:set(Status, ?OFF_PUBLISHED),
        published_at = hecate_api_utils:get_field(published_at, E)
    }.

apply_retracted(E, #offering_state{} = State) ->
    State#offering_state{
        status = ?OFF_INITIATED,
        retracted_at = hecate_api_utils:get_field(retracted_at, E)
    }.

apply_amended(E, State) ->
    Fields = [
        plugin_name, display_name, description, icon, group_name, group_icon, github_repo, homepage, tags,
        oci_image, package_url, plugin_type, callback_module,
        org, version, manifest_tag, min_daemon_version, publisher_identity,
        selling_formula, license_type, fee_cents, fee_currency,
        duration_days, node_limit,
        manifest_url, manifest_checksum, author_signature,
        oci_image_verified, oci_image_digest
    ],
    lists:foldl(
        fun(Field, S) -> maybe_set(Field, hecate_api_utils:get_field(Field, E), S) end,
        State,
        Fields
    ).

apply_archived(E, #offering_state{status = Status} = State) ->
    State#offering_state{
        status = evoq_bit_flags:set(Status, ?OFF_ARCHIVED),
        archived_at = hecate_api_utils:get_field(archived_at, E)
    }.

%% --- Internal ---

%% Selectively update an offering_state field only when Value is not undefined.
maybe_set(_Field, undefined, State) -> State;
maybe_set(plugin_name, V, S)        -> S#offering_state{plugin_name = V};
maybe_set(display_name, V, S)       -> S#offering_state{display_name = V};
maybe_set(description, V, S)        -> S#offering_state{description = V};
maybe_set(icon, V, S)               -> S#offering_state{icon = V};
maybe_set(group_name, V, S)         -> S#offering_state{group_name = V};
maybe_set(group_icon, V, S)         -> S#offering_state{group_icon = V};
maybe_set(github_repo, V, S)        -> S#offering_state{github_repo = V};
maybe_set(homepage, V, S)           -> S#offering_state{homepage = V};
maybe_set(tags, V, S)               -> S#offering_state{tags = V};
maybe_set(oci_image, V, S)          -> S#offering_state{oci_image = V};
maybe_set(package_url, V, S)        -> S#offering_state{package_url = V};
maybe_set(plugin_type, V, S)        -> S#offering_state{plugin_type = V};
maybe_set(callback_module, V, S)    -> S#offering_state{callback_module = V};
maybe_set(org, V, S)                -> S#offering_state{org = V};
maybe_set(version, V, S)            -> S#offering_state{version = V};
maybe_set(manifest_tag, V, S)       -> S#offering_state{manifest_tag = V};
maybe_set(min_daemon_version, V, S) -> S#offering_state{min_daemon_version = V};
maybe_set(publisher_identity, V, S) -> S#offering_state{publisher_identity = V};
maybe_set(selling_formula, V, S)    -> S#offering_state{selling_formula = V};
maybe_set(license_type, V, S)       -> S#offering_state{license_type = V};
maybe_set(fee_cents, V, S)          -> S#offering_state{fee_cents = V};
maybe_set(fee_currency, V, S)       -> S#offering_state{fee_currency = V};
maybe_set(duration_days, V, S)      -> S#offering_state{duration_days = V};
maybe_set(node_limit, V, S)         -> S#offering_state{node_limit = V};
maybe_set(manifest_url, V, S)       -> S#offering_state{manifest_url = V};
maybe_set(manifest_checksum, V, S)  -> S#offering_state{manifest_checksum = V};
maybe_set(author_signature, V, S)   -> S#offering_state{author_signature = V};
maybe_set(oci_image_verified, V, S) -> S#offering_state{oci_image_verified = V};
maybe_set(oci_image_digest, V, S)   -> S#offering_state{oci_image_digest = V}.
