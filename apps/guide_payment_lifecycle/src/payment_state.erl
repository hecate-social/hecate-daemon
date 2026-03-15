%%% @doc Payment state module — implements evoq_state behaviour.
%%%
%%% Owns the payment_state record, initial state creation, event folding,
%%% and serialization. Extracted from payment_aggregate to separate
%%% state concerns from command validation.
%%% @end
-module(payment_state).

-behaviour(evoq_state).

-include("payment_status.hrl").
-include("payment_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #payment_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #payment_state{status = 0}.

-spec apply_event(state(), map()) -> state().

%% Normalize atom event_type to binary (from typed evoq_event modules)
apply_event(S, #{event_type := Type} = E) when is_atom(Type) ->
    apply_event(S, E#{event_type := atom_to_binary(Type, utf8)});

apply_event(S, #{event_type := <<"payment_initiated_v1">>} = E) -> apply_initiated(E, S);
apply_event(S, #{event_type := <<"payment_archived_v1">>} = E)  -> apply_archived(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#payment_state{} = S) ->
    #{
        payment_id     => S#payment_state.payment_id,
        consumer_id    => S#payment_state.consumer_id,
        procurement_id => S#payment_state.procurement_id,
        offering_id    => S#payment_state.offering_id,
        plugin_id      => S#payment_state.plugin_id,
        amount_cents   => S#payment_state.amount_cents,
        currency       => S#payment_state.currency,
        status         => S#payment_state.status,
        initiated_at   => S#payment_state.initiated_at,
        archived_at    => S#payment_state.archived_at
    }.

%% --- Apply helpers ---

apply_initiated(E, _State) ->
    #payment_state{
        payment_id = get_value(payment_id, E),
        consumer_id = get_value(consumer_id, E),
        procurement_id = get_value(procurement_id, E),
        offering_id = get_value(offering_id, E),
        plugin_id = get_value(plugin_id, E),
        amount_cents = get_value(amount_cents, E),
        currency = get_value(currency, E),
        status = ?PAY_INITIATED,
        initiated_at = get_value(initiated_at, E)
    }.

apply_archived(E, #payment_state{status = Status} = State) ->
    State#payment_state{
        status = evoq_bit_flags:set(Status, ?PAY_ARCHIVED),
        archived_at = get_value(archived_at, E)
    }.

%% --- Internal ---

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
