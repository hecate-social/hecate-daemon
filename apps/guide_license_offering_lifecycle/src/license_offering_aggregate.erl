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

-export([state_module/0, init/1, execute/2, apply/2]).
-export([flag_map/0]).

-type state() :: #offering_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> offering_state.

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?OFF_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, offering_state:new(AggregateId)}.

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
    offering_state:apply_event(State, Event).

%% --- Internal ---

get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
