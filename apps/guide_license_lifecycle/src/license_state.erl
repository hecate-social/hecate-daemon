%%% @doc License aggregate state module.
%%%
%%% Owns the license_state record shape, initial state creation,
%%% event folding (apply), and serialization.
%%% @end
-module(license_state).

-behaviour(evoq_state).

-include("license_status.hrl").
-include("license_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #license_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #license_state{status = 0}.

-spec apply_event(state(), map()) -> state().

apply_event(S, #{event_type := <<"license_initiated_v1">>} = E)        -> apply_initiated(E, S);
apply_event(S, #{event_type := <<"offering_terms_accepted_v1">>} = E)  -> apply_accepted(E, S);
apply_event(S, #{event_type := <<"offering_terms_rejected_v1">>} = E)  -> apply_rejected(E, S);
apply_event(S, #{event_type := <<"license_bought_v1">>} = E)           -> apply_bought(E, S);
apply_event(S, #{event_type := <<"license_abandoned_v1">>} = E)        -> apply_abandoned(E, S);
apply_event(S, #{event_type := <<"license_granted_v1">>} = E)          -> apply_granted(E, S);
apply_event(S, #{event_type := <<"license_expired_v1">>} = E)          -> apply_expired(E, S);
apply_event(S, #{event_type := <<"license_renewed_v1">>} = E)          -> apply_renewed(E, S);
apply_event(S, #{event_type := <<"license_revoked_v1">>} = E)          -> apply_revoked(E, S);
apply_event(S, #{event_type := <<"license_archived_v1">>} = E)        -> apply_archived(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#license_state{} = S) ->
    #{
        license_id         => S#license_state.license_id,
        consumer_id        => S#license_state.consumer_id,
        offering_id        => S#license_state.offering_id,
        plugin_id          => S#license_state.plugin_id,
        status             => S#license_state.status,
        plugin_name        => S#license_state.plugin_name,
        display_name       => S#license_state.display_name,
        description        => S#license_state.description,
        icon               => S#license_state.icon,
        group_name         => S#license_state.group_name,
        group_icon         => S#license_state.group_icon,
        github_repo        => S#license_state.github_repo,
        oci_image          => S#license_state.oci_image,
        plugin_type        => S#license_state.plugin_type,
        callback_module    => S#license_state.callback_module,
        package_url        => S#license_state.package_url,
        selling_formula    => S#license_state.selling_formula,
        author_id          => S#license_state.author_id,
        license_type       => S#license_state.license_type,
        fee_cents          => S#license_state.fee_cents,
        fee_currency       => S#license_state.fee_currency,
        duration_days      => S#license_state.duration_days,
        node_limit         => S#license_state.node_limit,
        org                => S#license_state.org,
        version            => S#license_state.version,
        manifest_tag       => S#license_state.manifest_tag,
        tags               => S#license_state.tags,
        homepage           => S#license_state.homepage,
        min_daemon_version => S#license_state.min_daemon_version,
        publisher_identity => S#license_state.publisher_identity,
        manifest_url       => S#license_state.manifest_url,
        manifest_checksum  => S#license_state.manifest_checksum,
        author_signature   => S#license_state.author_signature,
        oci_image_verified => S#license_state.oci_image_verified,
        oci_image_digest   => S#license_state.oci_image_digest,
        initiated_at       => S#license_state.initiated_at,
        accepted_at        => S#license_state.accepted_at,
        rejected_at        => S#license_state.rejected_at,
        bought_at          => S#license_state.bought_at,
        abandoned_at       => S#license_state.abandoned_at,
        granted_at         => S#license_state.granted_at,
        expired_at         => S#license_state.expired_at,
        renewed_at         => S#license_state.renewed_at,
        revoked_at         => S#license_state.revoked_at,
        archived_at        => S#license_state.archived_at
    }.

%% --- Apply helpers ---

apply_initiated(E, State) ->
    State#license_state{
        license_id         = gf(license_id, E),
        consumer_id        = gf(consumer_id, E),
        offering_id        = gf(offering_id, E),
        plugin_id          = gf(plugin_id, E),
        plugin_name        = gf(plugin_name, E),
        display_name       = gf(display_name, E),
        description        = gf(description, E),
        icon               = gf(icon, E),
        group_name         = gf(group_name, E),
        group_icon         = gf(group_icon, E),
        github_repo        = gf(github_repo, E),
        oci_image          = gf(oci_image, E),
        plugin_type        = gf(plugin_type, E),
        callback_module    = gf(callback_module, E),
        package_url        = gf(package_url, E),
        selling_formula    = gf(selling_formula, E),
        author_id          = gf(author_id, E),
        license_type       = gf(license_type, E),
        fee_cents          = gf(fee_cents, E),
        fee_currency       = gf(fee_currency, E),
        duration_days      = gf(duration_days, E),
        node_limit         = gf(node_limit, E),
        org                = gf(org, E),
        version            = gf(version, E),
        manifest_tag       = gf(manifest_tag, E),
        tags               = gf(tags, E),
        homepage           = gf(homepage, E),
        min_daemon_version = gf(min_daemon_version, E),
        publisher_identity = gf(publisher_identity, E),
        manifest_url       = gf(manifest_url, E),
        manifest_checksum  = gf(manifest_checksum, E),
        author_signature   = gf(author_signature, E),
        oci_image_verified = gf(oci_image_verified, E),
        oci_image_digest   = gf(oci_image_digest, E),
        status             = evoq_bit_flags:set(0, ?LIC_INITIATED),
        initiated_at       = gf(initiated_at, E)
    }.

apply_accepted(_E, #license_state{status = Status} = State) ->
    State#license_state{
        status      = evoq_bit_flags:set(Status, ?LIC_ACCEPTED),
        accepted_at = erlang:system_time(millisecond)
    }.

apply_rejected(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_ARCHIVED),
        rejected_at = gf(rejected_at, E)
    }.

apply_bought(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_BOUGHT),
        bought_at = gf(bought_at, E)
    }.

apply_abandoned(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_ARCHIVED),
        abandoned_at = gf(abandoned_at, E)
    }.

apply_granted(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_GRANTED),
        granted_at = gf(granted_at, E)
    }.

apply_expired(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_EXPIRED),
        expired_at = gf(expired_at, E)
    }.

apply_renewed(E, #license_state{status = Status} = State) ->
    NewStatus = evoq_bit_flags:unset(Status, ?LIC_EXPIRED),
    State#license_state{
        status = evoq_bit_flags:set(NewStatus, ?LIC_GRANTED),
        renewed_at = gf(renewed_at, E)
    }.

apply_revoked(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_REVOKED),
        revoked_at = gf(revoked_at, E)
    }.

apply_archived(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_ARCHIVED),
        archived_at = gf(archived_at, E)
    }.

%% --- Internal ---

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
