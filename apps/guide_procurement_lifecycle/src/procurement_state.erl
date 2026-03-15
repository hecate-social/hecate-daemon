%%% @doc Procurement state module — implements evoq_state behaviour.
%%%
%%% Owns the procurement_state record, initial state creation, event folding,
%%% and serialization. Extracted from procurement_aggregate to separate
%%% state concerns from command validation.
%%% @end
-module(procurement_state).

-behaviour(evoq_state).

-include("procurement_status.hrl").
-include("procurement_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #procurement_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #procurement_state{status = 0}.

-spec apply_event(state(), map()) -> state().

%% Normalize atom event_type to binary (from typed evoq_event modules)
apply_event(S, #{event_type := Type} = E) when is_atom(Type) ->
    apply_event(S, E#{event_type := atom_to_binary(Type, utf8)});

apply_event(S, #{event_type := <<"procurement_initiated_v1">>} = E) -> apply_initiated(E, S);
apply_event(S, #{event_type := <<"procurement_archived_v1">>} = E)  -> apply_archived(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#procurement_state{} = S) ->
    #{
        procurement_id => S#procurement_state.procurement_id,
        consumer_id    => S#procurement_state.consumer_id,
        offering_id    => S#procurement_state.offering_id,
        plugin_id      => S#procurement_state.plugin_id,
        author_id      => S#procurement_state.author_id,
        status         => S#procurement_state.status,
        initiated_at   => S#procurement_state.initiated_at,
        archived_at    => S#procurement_state.archived_at
    }.

%% --- Apply helpers ---

apply_initiated(E, State) ->
    State#procurement_state{
        procurement_id = get_value(procurement_id, E),
        consumer_id = get_value(consumer_id, E),
        offering_id = get_value(offering_id, E),
        plugin_id = get_value(plugin_id, E),
        author_id = get_value(author_id, E),
        status = evoq_bit_flags:set(0, ?PROC_INITIATED),
        initiated_at = get_value(initiated_at, E)
    }.

apply_archived(E, #procurement_state{status = Status} = State) ->
    State#procurement_state{
        status = evoq_bit_flags:set(Status, ?PROC_ARCHIVED),
        archived_at = get_value(archived_at, E)
    }.

%% --- Internal ---

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
