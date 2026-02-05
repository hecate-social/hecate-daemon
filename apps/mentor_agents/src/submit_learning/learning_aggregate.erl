%%% @doc Learning aggregate
%%% Maintains learning state and applies events.
%%% Shared across all learning lifecycle spokes.
-module(learning_aggregate).

-export([execute/2, apply_event/2, initial_state/0]).

-define(SUBMITTED,  1).   %% 2^0
-define(VALIDATED,  2).   %% 2^1
-define(REJECTED,   4).   %% 2^2
-define(ENDORSED,   8).   %% 2^3
-define(DISPUTED,  16).   %% 2^4
-define(RESOLVED,  32).   %% 2^5

-record(learning_state, {
    learning_id    :: binary() | undefined,
    submitter_id   :: binary() | undefined,
    category       :: binary() | undefined,
    domain         :: binary() | undefined,
    tags           :: [binary()],
    title          :: binary() | undefined,
    description    :: binary() | undefined,
    bad_example    :: binary() | undefined,
    good_example   :: binary() | undefined,
    context        :: binary() | undefined,
    severity       :: binary() | undefined,
    confidence     :: float(),
    source         :: binary() | undefined,
    status         :: non_neg_integer(),
    validator_id   :: binary() | undefined,
    endorser_ids   :: [binary()],
    disputer_ids   :: [binary()],
    submitted_at   :: non_neg_integer() | undefined,
    validated_at   :: non_neg_integer() | undefined
}).

-type state() :: #learning_state{}.
-export_type([state/0]).

-spec initial_state() -> state().
initial_state() ->
    #learning_state{
        learning_id = undefined,
        submitter_id = undefined,
        category = undefined,
        domain = undefined,
        tags = [],
        title = undefined,
        description = undefined,
        bad_example = undefined,
        good_example = undefined,
        context = undefined,
        severity = undefined,
        confidence = 0.5,
        source = undefined,
        status = 0,
        validator_id = undefined,
        endorser_ids = [],
        disputer_ids = [],
        submitted_at = undefined,
        validated_at = undefined
    }.

%% @doc Execute command against aggregate state
-spec execute(map(), state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := <<"submit_learning">>} = Payload, State) ->
    execute_submit(Payload, State);
execute(#{command_type := <<"validate_learning">>} = Payload, State) ->
    execute_validate(Payload, State);
execute(#{command_type := <<"reject_learning">>} = Payload, State) ->
    execute_reject(Payload, State);
execute(#{command_type := <<"endorse_learning">>} = Payload, State) ->
    execute_endorse(Payload, State);
execute(#{command_type := <<"dispute_learning">>} = Payload, State) ->
    execute_dispute(Payload, State);
execute(#{command_type := <<"resolve_dispute">>} = Payload, State) ->
    execute_resolve(Payload, State);
execute(Payload, State) ->
    %% Default: submit_learning
    execute_submit(Payload, State).

execute_submit(Payload, #learning_state{learning_id = undefined}) ->
    {ok, Cmd} = submit_learning_v1:from_map(Payload),
    convert_events(maybe_submit_learning:handle(Cmd), fun learning_submitted_v1:to_map/1);
execute_submit(_Payload, _State) ->
    {error, learning_already_exists}.

execute_validate(Payload, #learning_state{status = S}) when S band ?SUBMITTED =/= 0, S band ?VALIDATED =:= 0, S band ?REJECTED =:= 0 ->
    {ok, Cmd} = validate_learning_v1:from_map(Payload),
    convert_events(maybe_validate_learning:handle(Cmd), fun learning_validated_v1:to_map/1);
execute_validate(_Payload, #learning_state{learning_id = undefined}) ->
    {error, learning_not_found};
execute_validate(_Payload, _State) ->
    {error, learning_not_pending}.

execute_reject(Payload, #learning_state{status = S}) when S band ?SUBMITTED =/= 0, S band ?VALIDATED =:= 0, S band ?REJECTED =:= 0 ->
    {ok, Cmd} = reject_learning_v1:from_map(Payload),
    convert_events(maybe_reject_learning:handle(Cmd), fun learning_rejected_v1:to_map/1);
execute_reject(_Payload, #learning_state{learning_id = undefined}) ->
    {error, learning_not_found};
execute_reject(_Payload, _State) ->
    {error, learning_not_pending}.

execute_endorse(Payload, #learning_state{status = S, endorser_ids = Endorsers}) when S band ?VALIDATED =/= 0 ->
    AgentId = maps:get(agent_id, Payload, maps:get(<<"agent_id">>, Payload, undefined)),
    case lists:member(AgentId, Endorsers) of
        true -> {error, already_endorsed};
        false ->
            {ok, Cmd} = endorse_learning_v1:from_map(Payload),
            convert_events(maybe_endorse_learning:handle(Cmd), fun learning_endorsed_v1:to_map/1)
    end;
execute_endorse(_Payload, #learning_state{learning_id = undefined}) ->
    {error, learning_not_found};
execute_endorse(_Payload, _State) ->
    {error, learning_not_validated}.

execute_dispute(Payload, #learning_state{status = S, disputer_ids = Disputers}) when S band ?VALIDATED =/= 0 ->
    AgentId = maps:get(agent_id, Payload, maps:get(<<"agent_id">>, Payload, undefined)),
    case lists:member(AgentId, Disputers) of
        true -> {error, already_disputed};
        false ->
            {ok, Cmd} = dispute_learning_v1:from_map(Payload),
            convert_events(maybe_dispute_learning:handle(Cmd), fun learning_disputed_v1:to_map/1)
    end;
execute_dispute(_Payload, #learning_state{learning_id = undefined}) ->
    {error, learning_not_found};
execute_dispute(_Payload, _State) ->
    {error, learning_not_validated}.

execute_resolve(Payload, #learning_state{status = S}) when S band ?DISPUTED =/= 0, S band ?RESOLVED =:= 0 ->
    {ok, Cmd} = resolve_dispute_v1:from_map(Payload),
    convert_events(maybe_resolve_dispute:handle(Cmd), fun dispute_resolved_v1:to_map/1);
execute_resolve(_Payload, #learning_state{learning_id = undefined}) ->
    {error, learning_not_found};
execute_resolve(_Payload, _State) ->
    {error, learning_not_disputed}.

convert_events({ok, Events}, ToMapFun) ->
    EventMaps = [ToMapFun(E) || E <- Events],
    {ok, EventMaps};
convert_events({error, Reason}, _ToMapFun) ->
    {error, Reason}.

%% @doc Apply event to state (event sourcing)
-spec apply_event(map(), state()) -> state().
apply_event(#{event_type := <<"learning_submitted_v1">>} = E, State) ->
    State#learning_state{
        learning_id = maps:get(learning_id, E),
        submitter_id = maps:get(submitter_id, E),
        category = maps:get(category, E),
        domain = maps:get(domain, E),
        tags = maps:get(tags, E, []),
        title = maps:get(title, E),
        description = maps:get(description, E, undefined),
        bad_example = maps:get(bad_example, E, undefined),
        good_example = maps:get(good_example, E, undefined),
        context = maps:get(context, E, undefined),
        severity = maps:get(severity, E, <<"suggestion">>),
        confidence = maps:get(confidence, E, 0.5),
        source = maps:get(source, E, <<"discovered">>),
        status = ?SUBMITTED,
        submitted_at = maps:get(submitted_at, E)
    };
apply_event(#{event_type := <<"learning_validated_v1">>} = E, State) ->
    State#learning_state{
        status = State#learning_state.status bor ?VALIDATED,
        validator_id = maps:get(validator_id, E),
        validated_at = maps:get(validated_at, E)
    };
apply_event(#{event_type := <<"learning_rejected_v1">>} = E, State) ->
    State#learning_state{
        status = State#learning_state.status bor ?REJECTED,
        validator_id = maps:get(validator_id, E)
    };
apply_event(#{event_type := <<"learning_endorsed_v1">>} = E, State) ->
    AgentId = maps:get(agent_id, E),
    State#learning_state{
        status = State#learning_state.status bor ?ENDORSED,
        endorser_ids = [AgentId | State#learning_state.endorser_ids]
    };
apply_event(#{event_type := <<"learning_disputed_v1">>} = E, State) ->
    AgentId = maps:get(agent_id, E),
    State#learning_state{
        status = State#learning_state.status bor ?DISPUTED,
        disputer_ids = [AgentId | State#learning_state.disputer_ids]
    };
apply_event(#{event_type := <<"dispute_resolved_v1">>} = _E, State) ->
    State#learning_state{
        status = State#learning_state.status bor ?RESOLVED
    };
apply_event(_E, State) ->
    State.
