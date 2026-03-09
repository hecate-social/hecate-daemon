%%% @doc Consumer license aggregate.
%%%
%%% Stream: license-{consumer_id}-{plugin_id}
%%% Store: licenses_store
%%%
%%% Lifecycle:
%%%   1. initiate_license (birth — full offering snapshot deep-copied)
%%%   2. accept_offering_terms (lightweight consent confirmation)
%%%      OR reject_offering_terms (terminal)
%%%   3. buy_license (paid path) OR free auto-grants via PM
%%%      OR abandon_license (terminal)
%%%   4. grant_license (PM auto-grants after buy or free acceptance)
%%%   5. expire_license / renew_license / revoke_license / archive_license
%%% @end
-module(license_aggregate).

-behaviour(evoq_aggregate).

-include("license_status.hrl").
-include("license_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-type state() :: #license_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?LIC_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #license_state{status = 0}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate
execute(#license_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_license">> -> execute_initiate_license(Payload);
        _ -> {error, license_not_initiated}
    end;

%% Archived — terminal, nothing allowed
execute(#license_state{status = S}, _Payload) when S band ?LIC_ARCHIVED =/= 0 ->
    {error, license_archived};

%% Revoked — only archive
execute(#license_state{status = S}, Payload) when S band ?LIC_REVOKED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, license_revoked}
    end;

%% Expired — renew or archive
execute(#license_state{status = S}, Payload) when S band ?LIC_EXPIRED =/= 0 ->
    case get_command_type(Payload) of
        <<"renew_license">>   -> execute_renew_license(Payload);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, license_expired}
    end;

%% Granted — expire, revoke, or archive
execute(#license_state{status = S}, Payload) when S band ?LIC_GRANTED =/= 0 ->
    case get_command_type(Payload) of
        <<"expire_license">>  -> execute_expire_license(Payload);
        <<"revoke_license">>  -> execute_revoke_license(Payload);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, already_granted}
    end;

%% Bought — only grant (PM dispatches this)
execute(#license_state{status = S} = State, Payload) when S band ?LIC_BOUGHT =/= 0 ->
    case get_command_type(Payload) of
        <<"grant_license">>   -> execute_grant_license(State, Payload);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, awaiting_grant}
    end;

%% Accepted — buy (paid path), abandon, or grant (free path via PM)
execute(#license_state{status = S} = State, Payload) when S band ?LIC_ACCEPTED =/= 0 ->
    case get_command_type(Payload) of
        <<"buy_license">>       -> execute_buy_license(Payload);
        <<"grant_license">>     -> execute_grant_license(State, Payload);
        <<"abandon_license">>   -> execute_abandon_license(Payload);
        <<"archive_license">>   -> execute_archive_license(Payload);
        _ -> {error, not_bought}
    end;

%% Initiated — accept or reject terms
execute(#license_state{status = S} = State, Payload) when S band ?LIC_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"accept_offering_terms">>  -> execute_accept_offering_terms(State, Payload);
        <<"reject_offering_terms">>  -> execute_reject_offering_terms(Payload);
        <<"archive_license">>        -> execute_archive_license(Payload);
        _ -> {error, not_accepted}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_license(Payload) ->
    {ok, Cmd} = initiate_license_v1:from_map(Payload),
    convert_events(maybe_initiate_license:handle(Cmd), fun license_initiated_v1:to_map/1).

execute_accept_offering_terms(State, Payload) ->
    {ok, Cmd} = accept_offering_terms_v1:from_map(Payload),
    convert_events(maybe_accept_offering_terms:handle(Cmd, State), fun offering_terms_accepted_v1:to_map/1).

execute_reject_offering_terms(Payload) ->
    {ok, Cmd} = reject_offering_terms_v1:from_map(Payload),
    convert_events(maybe_reject_offering_terms:handle(Cmd), fun offering_terms_rejected_v1:to_map/1).

execute_buy_license(Payload) ->
    {ok, Cmd} = buy_license_v1:from_map(Payload),
    convert_events(maybe_buy_license:handle(Cmd), fun license_bought_v1:to_map/1).

execute_abandon_license(Payload) ->
    {ok, Cmd} = abandon_license_v1:from_map(Payload),
    convert_events(maybe_abandon_license:handle(Cmd), fun license_abandoned_v1:to_map/1).

execute_grant_license(State, Payload) ->
    {ok, Cmd} = grant_license_v1:from_map(Payload),
    convert_events(maybe_grant_license:handle(Cmd, State), fun license_granted_v1:to_map/1).

execute_expire_license(Payload) ->
    {ok, Cmd} = expire_license_v1:from_map(Payload),
    convert_events(maybe_expire_license:handle(Cmd), fun license_expired_v1:to_map/1).

execute_renew_license(Payload) ->
    {ok, Cmd} = renew_license_v1:from_map(Payload),
    convert_events(maybe_renew_license:handle(Cmd), fun license_renewed_v1:to_map/1).

execute_revoke_license(Payload) ->
    {ok, Cmd} = revoke_license_v1:from_map(Payload),
    convert_events(maybe_revoke_license:handle(Cmd), fun license_revoked_v1:to_map/1).

execute_archive_license(Payload) ->
    {ok, Cmd} = archive_license_v1:from_map(Payload),
    convert_events(maybe_archive_license:handle(Cmd), fun license_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"license_initiated_v1">>} = E, S)          -> apply_initiated(E, S);
apply_event(#{event_type := <<"license_initiated_v1">>} = E, S)                -> apply_initiated(E, S);
apply_event(#{<<"event_type">> := <<"offering_terms_accepted_v1">>} = E, S)    -> apply_accepted(E, S);
apply_event(#{event_type := <<"offering_terms_accepted_v1">>} = E, S)          -> apply_accepted(E, S);
apply_event(#{<<"event_type">> := <<"offering_terms_rejected_v1">>} = E, S)    -> apply_rejected(E, S);
apply_event(#{event_type := <<"offering_terms_rejected_v1">>} = E, S)          -> apply_rejected(E, S);
apply_event(#{<<"event_type">> := <<"license_bought_v1">>} = E, S)             -> apply_bought(E, S);
apply_event(#{event_type := <<"license_bought_v1">>} = E, S)                   -> apply_bought(E, S);
apply_event(#{<<"event_type">> := <<"license_abandoned_v1">>} = E, S)          -> apply_abandoned(E, S);
apply_event(#{event_type := <<"license_abandoned_v1">>} = E, S)                -> apply_abandoned(E, S);
apply_event(#{<<"event_type">> := <<"license_granted_v1">>} = E, S)            -> apply_granted(E, S);
apply_event(#{event_type := <<"license_granted_v1">>} = E, S)                  -> apply_granted(E, S);
apply_event(#{<<"event_type">> := <<"license_expired_v1">>} = E, S)            -> apply_expired(E, S);
apply_event(#{event_type := <<"license_expired_v1">>} = E, S)                  -> apply_expired(E, S);
apply_event(#{<<"event_type">> := <<"license_renewed_v1">>} = E, S)            -> apply_renewed(E, S);
apply_event(#{event_type := <<"license_renewed_v1">>} = E, S)                  -> apply_renewed(E, S);
apply_event(#{<<"event_type">> := <<"license_revoked_v1">>} = E, S)            -> apply_revoked(E, S);
apply_event(#{event_type := <<"license_revoked_v1">>} = E, S)                  -> apply_revoked(E, S);
apply_event(#{<<"event_type">> := <<"license_archived_v1">>} = E, S)           -> apply_archived(E, S);
apply_event(#{event_type := <<"license_archived_v1">>} = E, S)                 -> apply_archived(E, S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_initiated(E, State) ->
    State#license_state{
        license_id         = gf(license_id, E),
        consumer_id        = gf(consumer_id, E),
        offering_id        = gf(offering_id, E),
        plugin_id          = gf(plugin_id, E),
        %% Full offering snapshot deep-copied at birth
        plugin_name        = gf(plugin_name, E),
        description        = gf(description, E),
        icon               = gf(icon, E),
        group_name         = gf(group_name, E),
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

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
