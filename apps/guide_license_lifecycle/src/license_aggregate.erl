%%% @doc License aggregate.
%%%
%%% Stream: license-{seller_id}-{plugin_id} (seller) or license-{user_id}-{plugin_id} (buyer)
%%% Store: licenses_store
%%%
%%% Lifecycle:
%%%   Seller side:
%%%   1. initiate_license (birth event - license_initiated_v1)
%%%   2. announce_license (license_announced_v1)
%%%   3. publish_license (license_published_v1)
%%%
%%%   Buyer side:
%%%   4. buy_license (requires LIC_PUBLISHED - license_bought_v1)
%%%   5. revoke_license
%%%   6. archive_license (walking skeleton)
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

%% Fresh aggregate — only initiate_license allowed (seller birth)
execute(#license_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_license">> -> execute_initiate_license(Payload);
        _ -> {error, license_not_initiated}
    end;

%% Archived — nothing allowed
execute(#license_state{status = S}, _Payload) when S band ?LIC_ARCHIVED =/= 0 ->
    {error, license_archived};

%% Revoked — nothing allowed except archive
execute(#license_state{status = S}, Payload) when S band ?LIC_REVOKED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, license_revoked}
    end;

%% Licensed — route by command type (buyer operations)
execute(#license_state{status = S}, Payload) when S band ?LIC_LICENSED =/= 0 ->
    case get_command_type(Payload) of
        <<"revoke_license">>  -> execute_revoke_license(Payload);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, unknown_command}
    end;

%% Published — buyer can buy, seller can retract or archive
execute(#license_state{status = S}, Payload) when S band ?LIC_PUBLISHED =/= 0 ->
    case get_command_type(Payload) of
        <<"buy_license">>      -> execute_buy_license(Payload);
        <<"retract_license">>  -> execute_retract_license(Payload);
        <<"archive_license">>  -> execute_archive_license(Payload);
        _ -> {error, not_licensed}
    end;

%% Announced — seller can publish, amend, retract, or archive
execute(#license_state{status = S}, Payload) when S band ?LIC_ANNOUNCED =/= 0 ->
    case get_command_type(Payload) of
        <<"publish_license">>  -> execute_publish_license(Payload);
        <<"amend_license">>    -> execute_amend_license(Payload);
        <<"retract_license">>  -> execute_retract_license(Payload);
        <<"archive_license">>  -> execute_archive_license(Payload);
        _ -> {error, not_published}
    end;

%% Initiated — seller can announce, amend, or archive
execute(#license_state{status = S}, Payload) when S band ?LIC_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"announce_license">>        -> execute_announce_license(Payload);
        <<"amend_license">>   -> execute_amend_license(Payload);
        <<"archive_license">>         -> execute_archive_license(Payload);
        _ -> {error, not_announced}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers (seller side) ---

execute_initiate_license(Payload) ->
    {ok, Cmd} = initiate_license_v1:from_map(Payload),
    convert_events(maybe_initiate_license:handle(Cmd), fun license_initiated_v1:to_map/1).

execute_announce_license(Payload) ->
    {ok, Cmd} = announce_license_v1:from_map(Payload),
    convert_events(maybe_announce_license:handle(Cmd), fun license_announced_v1:to_map/1).

execute_publish_license(Payload) ->
    {ok, Cmd} = publish_license_v1:from_map(Payload),
    convert_events(maybe_publish_license:handle(Cmd), fun license_published_v1:to_map/1).

execute_retract_license(Payload) ->
    {ok, Cmd} = retract_license_v1:from_map(Payload),
    convert_events(maybe_retract_license:handle(Cmd), fun license_retracted_v1:to_map/1).

%% --- Command handlers (buyer side) ---

execute_buy_license(Payload) ->
    {ok, Cmd} = buy_license_v1:from_map(Payload),
    convert_events(maybe_buy_license:handle(Cmd), fun license_bought_v1:to_map/1).

execute_revoke_license(Payload) ->
    {ok, Cmd} = revoke_license_v1:from_map(Payload),
    convert_events(maybe_revoke_license:handle(Cmd), fun license_revoked_v1:to_map/1).

execute_archive_license(Payload) ->
    {ok, Cmd} = archive_license_v1:from_map(Payload),
    convert_events(maybe_archive_license:handle(Cmd), fun license_archived_v1:to_map/1).

%% --- Command handlers (amendment) ---

execute_amend_license(Payload) ->
    {ok, Cmd} = amend_license_v1:from_map(Payload),
    convert_events(maybe_amend_license:handle(Cmd), fun license_amended_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

%% Seller-side events
apply_event(#{<<"event_type">> := <<"license_initiated_v1">>} = E, S)  -> apply_initiated(E, S);
apply_event(#{event_type := <<"license_initiated_v1">>} = E, S)        -> apply_initiated(E, S);
apply_event(#{<<"event_type">> := <<"license_announced_v1">>} = E, S)  -> apply_announced(E, S);
apply_event(#{event_type := <<"license_announced_v1">>} = E, S)        -> apply_announced(E, S);
apply_event(#{<<"event_type">> := <<"license_published_v1">>} = E, S)  -> apply_published(E, S);
apply_event(#{event_type := <<"license_published_v1">>} = E, S)        -> apply_published(E, S);
apply_event(#{<<"event_type">> := <<"license_retracted_v1">>} = E, S)  -> apply_retracted(E, S);
apply_event(#{event_type := <<"license_retracted_v1">>} = E, S)        -> apply_retracted(E, S);

%% Amendment events
apply_event(#{<<"event_type">> := <<"license_amended_v1">>} = E, S) -> apply_amended(E, S);
apply_event(#{event_type := <<"license_amended_v1">>} = E, S)       -> apply_amended(E, S);

%% Buyer-side events
apply_event(#{<<"event_type">> := <<"license_bought_v1">>} = E, S)   -> apply_bought(E, S);
apply_event(#{event_type := <<"license_bought_v1">>} = E, S)         -> apply_bought(E, S);
apply_event(#{<<"event_type">> := <<"license_revoked_v1">>} = E, S)  -> apply_revoked(E, S);
apply_event(#{event_type := <<"license_revoked_v1">>} = E, S)       -> apply_revoked(E, S);
apply_event(#{<<"event_type">> := <<"license_archived_v1">>} = E, S) -> apply_archived(E, S);
apply_event(#{event_type := <<"license_archived_v1">>} = E, S)     -> apply_archived(E, S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers (seller side) ---

apply_initiated(E, State) ->
    State#license_state{
        license_id = hecate_api_utils:get_field(license_id, E),
        plugin_id = hecate_api_utils:get_field(plugin_id, E),
        plugin_name = hecate_api_utils:get_field(plugin_name, E),
        description = hecate_api_utils:get_field(description, E),
        icon = hecate_api_utils:get_field(icon, E),
        group_name = hecate_api_utils:get_field(group_name, E),
        github_repo = hecate_api_utils:get_field(github_repo, E),
        oci_image = hecate_api_utils:get_field(oci_image, E),
        selling_formula = hecate_api_utils:get_field(selling_formula, E),
        seller_id = hecate_api_utils:get_field(seller_id, E),
        license_type = hecate_api_utils:get_field(license_type, E),
        fee_cents = hecate_api_utils:get_field(fee_cents, E),
        fee_currency = hecate_api_utils:get_field(fee_currency, E),
        duration_days = hecate_api_utils:get_field(duration_days, E),
        node_limit = hecate_api_utils:get_field(node_limit, E),
        org = hecate_api_utils:get_field(org, E),
        version = hecate_api_utils:get_field(version, E),
        manifest_tag = hecate_api_utils:get_field(manifest_tag, E),
        tags = hecate_api_utils:get_field(tags, E),
        homepage = hecate_api_utils:get_field(homepage, E),
        min_daemon_version = hecate_api_utils:get_field(min_daemon_version, E),
        publisher_identity = hecate_api_utils:get_field(publisher_identity, E),
        manifest_url = hecate_api_utils:get_field(manifest_url, E),
        manifest_checksum = hecate_api_utils:get_field(manifest_checksum, E),
        seller_signature = hecate_api_utils:get_field(seller_signature, E),
        oci_image_verified = hecate_api_utils:get_field(oci_image_verified, E),
        oci_image_digest = hecate_api_utils:get_field(oci_image_digest, E),
        status = evoq_bit_flags:set(0, ?LIC_INITIATED),
        initiated_at = hecate_api_utils:get_field(initiated_at, E)
    }.

apply_announced(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_ANNOUNCED),
        announced_at = hecate_api_utils:get_field(announced_at, E)
    }.

apply_published(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_PUBLISHED),
        published_at = hecate_api_utils:get_field(published_at, E)
    }.

apply_retracted(E, #license_state{} = State) ->
    State#license_state{
        status = ?LIC_INITIATED,
        retracted_at = hecate_api_utils:get_field(retracted_at, E)
    }.

%% --- Apply helpers (amendment) ---

apply_amended(E, State) ->
    Fields = [
        plugin_name, description, icon, group_name, github_repo, oci_image,
        org, version, manifest_tag, tags, homepage,
        min_daemon_version, publisher_identity,
        selling_formula, license_type, fee_cents, fee_currency,
        duration_days, node_limit,
        manifest_url, manifest_checksum, seller_signature,
        oci_image_verified, oci_image_digest
    ],
    lists:foldl(
        fun(Field, S) -> maybe_set(Field, hecate_api_utils:get_field(Field, E), S) end,
        State,
        Fields
    ).

%% --- Apply helpers (buyer side) ---

apply_bought(E, #license_state{status = Status} = State) ->
    State#license_state{
        user_id = hecate_api_utils:get_field(user_id, E),
        status = evoq_bit_flags:set(Status, ?LIC_LICENSED),
        oci_image = hecate_api_utils:get_field(oci_image, E),
        granted_at = hecate_api_utils:get_field(granted_at, E)
    }.

apply_revoked(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_REVOKED),
        revoked_at = hecate_api_utils:get_field(revoked_at, E)
    }.

apply_archived(E, #license_state{status = Status} = State) ->
    State#license_state{
        status = evoq_bit_flags:set(Status, ?LIC_ARCHIVED),
        archived_at = hecate_api_utils:get_field(archived_at, E)
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

%% Selectively update a license_state field only when Value is not undefined.
maybe_set(_Field, undefined, State) -> State;
maybe_set(plugin_name, V, S)        -> S#license_state{plugin_name = V};
maybe_set(description, V, S)        -> S#license_state{description = V};
maybe_set(icon, V, S)               -> S#license_state{icon = V};
maybe_set(group_name, V, S)         -> S#license_state{group_name = V};
maybe_set(github_repo, V, S)        -> S#license_state{github_repo = V};
maybe_set(oci_image, V, S)          -> S#license_state{oci_image = V};
maybe_set(org, V, S)                -> S#license_state{org = V};
maybe_set(version, V, S)            -> S#license_state{version = V};
maybe_set(manifest_tag, V, S)       -> S#license_state{manifest_tag = V};
maybe_set(tags, V, S)               -> S#license_state{tags = V};
maybe_set(homepage, V, S)           -> S#license_state{homepage = V};
maybe_set(min_daemon_version, V, S) -> S#license_state{min_daemon_version = V};
maybe_set(publisher_identity, V, S) -> S#license_state{publisher_identity = V};
maybe_set(selling_formula, V, S)    -> S#license_state{selling_formula = V};
maybe_set(license_type, V, S)       -> S#license_state{license_type = V};
maybe_set(fee_cents, V, S)          -> S#license_state{fee_cents = V};
maybe_set(fee_currency, V, S)       -> S#license_state{fee_currency = V};
maybe_set(duration_days, V, S)      -> S#license_state{duration_days = V};
maybe_set(node_limit, V, S)         -> S#license_state{node_limit = V};
maybe_set(manifest_url, V, S)       -> S#license_state{manifest_url = V};
maybe_set(manifest_checksum, V, S)  -> S#license_state{manifest_checksum = V};
maybe_set(seller_signature, V, S)   -> S#license_state{seller_signature = V};
maybe_set(oci_image_verified, V, S) -> S#license_state{oci_image_verified = V};
maybe_set(oci_image_digest, V, S)   -> S#license_state{oci_image_digest = V}.
