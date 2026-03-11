%%% @doc License offering aggregate (author-side).
%%%
%%% Stream: offering-{author_id}-{plugin_id}
%%% Store: license_offerings_store
%%%
%%% Lifecycle:
%%%   1. initiate_offering (birth event - offering_initiated_v1)
%%%   2. draft_offering (save work in progress - offering_drafted_v1)
%%%   3. announce_offering (pre-publish - offering_announced_v1)
%%%   4. amend_offering (update fields - offering_amended_v1)
%%%   5. publish_offering (available on mesh - offering_published_v1)
%%%   6. retract_offering (pull back - offering_retracted_v1)
%%%   7. archive_offering (walking skeleton - offering_archived_v1)
%%% @end
-module(license_offering_aggregate).

-behaviour(evoq_aggregate).

-include("offering_status.hrl").
-include("offering_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-type state() :: #offering_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?OFF_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #offering_state{status = 0}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate - only initiate allowed
execute(#offering_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_offering">> -> execute_initiate_offering(Payload);
        _ -> {error, offering_not_initiated}
    end;

%% Archived - nothing allowed
execute(#offering_state{status = S}, _Payload) when S band ?OFF_ARCHIVED =/= 0 ->
    {error, offering_archived};

%% Published - retract, amend, or archive
execute(#offering_state{status = S}, Payload) when S band ?OFF_PUBLISHED =/= 0 ->
    case get_command_type(Payload) of
        <<"retract_offering">>  -> execute_retract_offering(Payload);
        <<"amend_offering">>    -> execute_amend_offering(Payload);
        <<"archive_offering">>  -> execute_archive_offering(Payload);
        _ -> {error, unknown_command}
    end;

%% Announced - publish, amend, retract, or archive
execute(#offering_state{status = S}, Payload) when S band ?OFF_ANNOUNCED =/= 0 ->
    case get_command_type(Payload) of
        <<"publish_offering">>  -> execute_publish_offering(Payload);
        <<"amend_offering">>    -> execute_amend_offering(Payload);
        <<"retract_offering">>  -> execute_retract_offering(Payload);
        <<"archive_offering">>  -> execute_archive_offering(Payload);
        _ -> {error, not_published}
    end;

%% Initiated - announce, draft, amend, or archive
execute(#offering_state{status = S}, Payload) when S band ?OFF_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"announce_offering">> -> execute_announce_offering(Payload);
        <<"draft_offering">>    -> execute_draft_offering(Payload);
        <<"amend_offering">>    -> execute_amend_offering(Payload);
        <<"archive_offering">>  -> execute_archive_offering(Payload);
        _ -> {error, not_announced}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_offering(Payload) ->
    {ok, Cmd} = initiate_offering_v1:from_map(Payload),
    convert_events(maybe_initiate_offering:handle(Cmd), fun offering_initiated_v1:to_map/1).

execute_draft_offering(Payload) ->
    {ok, Cmd} = draft_offering_v1:from_map(Payload),
    convert_events(maybe_draft_offering:handle(Cmd), fun offering_drafted_v1:to_map/1).

execute_announce_offering(Payload) ->
    {ok, Cmd} = announce_offering_v1:from_map(Payload),
    convert_events(maybe_announce_offering:handle(Cmd), fun offering_announced_v1:to_map/1).

execute_amend_offering(Payload) ->
    {ok, Cmd} = amend_offering_v1:from_map(Payload),
    convert_events(maybe_amend_offering:handle(Cmd), fun offering_amended_v1:to_map/1).

execute_publish_offering(Payload) ->
    {ok, Cmd} = publish_offering_v1:from_map(Payload),
    convert_events(maybe_publish_offering:handle(Cmd), fun offering_published_v1:to_map/1).

execute_retract_offering(Payload) ->
    {ok, Cmd} = retract_offering_v1:from_map(Payload),
    convert_events(maybe_retract_offering:handle(Cmd), fun offering_retracted_v1:to_map/1).

execute_archive_offering(Payload) ->
    {ok, Cmd} = archive_offering_v1:from_map(Payload),
    convert_events(maybe_archive_offering:handle(Cmd), fun offering_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"offering_initiated_v1">>} = E, S) -> apply_initiated(E, S);
apply_event(#{event_type := <<"offering_initiated_v1">>} = E, S)      -> apply_initiated(E, S);
apply_event(#{<<"event_type">> := <<"offering_drafted_v1">>} = E, S)  -> apply_drafted(E, S);
apply_event(#{event_type := <<"offering_drafted_v1">>} = E, S)        -> apply_drafted(E, S);
apply_event(#{<<"event_type">> := <<"offering_announced_v1">>} = E, S) -> apply_announced(E, S);
apply_event(#{event_type := <<"offering_announced_v1">>} = E, S)      -> apply_announced(E, S);
apply_event(#{<<"event_type">> := <<"offering_published_v1">>} = E, S) -> apply_published(E, S);
apply_event(#{event_type := <<"offering_published_v1">>} = E, S)      -> apply_published(E, S);
apply_event(#{<<"event_type">> := <<"offering_retracted_v1">>} = E, S) -> apply_retracted(E, S);
apply_event(#{event_type := <<"offering_retracted_v1">>} = E, S)      -> apply_retracted(E, S);
apply_event(#{<<"event_type">> := <<"offering_amended_v1">>} = E, S)  -> apply_amended(E, S);
apply_event(#{event_type := <<"offering_amended_v1">>} = E, S)        -> apply_amended(E, S);
apply_event(#{<<"event_type">> := <<"offering_archived_v1">>} = E, S) -> apply_archived(E, S);
apply_event(#{event_type := <<"offering_archived_v1">>} = E, S)      -> apply_archived(E, S);
%% Unknown - ignore
apply_event(_E, S) -> S.

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

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.

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
