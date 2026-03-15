%%% @doc Sale state module — implements evoq_state behaviour.
%%%
%%% Owns the sale_state record, initial state creation, event folding,
%%% and serialization. Extracted from sale_aggregate to separate
%%% state concerns from command validation.
%%% @end
-module(sale_state).

-behaviour(evoq_state).

-include("sale_status.hrl").
-include("sale_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #sale_state{}.
-export_type([state/0]).

%% --- evoq_state callbacks ---

-spec new(binary()) -> state().
new(_AggregateId) ->
    #sale_state{status = 0}.

-spec apply_event(state(), map()) -> state().

%% Normalize atom event_type to binary (from typed evoq_event modules)
apply_event(S, #{event_type := Type} = E) when is_atom(Type) ->
    apply_event(S, E#{event_type := atom_to_binary(Type, utf8)});

apply_event(S, #{event_type := <<"sale_initiated_v1">>} = E) -> apply_initiated(E, S);
apply_event(S, #{event_type := <<"sale_archived_v1">>} = E)  -> apply_archived(E, S);
%% Unknown — ignore
apply_event(S, _E) -> S.

-spec to_map(state()) -> map().
to_map(#sale_state{} = S) ->
    #{
        sale_id        => S#sale_state.sale_id,
        seller_id      => S#sale_state.seller_id,
        procurement_id => S#sale_state.procurement_id,
        offering_id    => S#sale_state.offering_id,
        plugin_id      => S#sale_state.plugin_id,
        status         => S#sale_state.status,
        initiated_at   => S#sale_state.initiated_at,
        archived_at    => S#sale_state.archived_at
    }.

%% --- Apply helpers ---

apply_initiated(E, _State) ->
    #sale_state{
        sale_id        = get_value(sale_id, E),
        seller_id      = get_value(seller_id, E),
        procurement_id = get_value(procurement_id, E),
        offering_id    = get_value(offering_id, E),
        plugin_id      = get_value(plugin_id, E),
        status         = evoq_bit_flags:set(0, ?SALE_INITIATED),
        initiated_at   = get_value(initiated_at, E)
    }.

apply_archived(E, #sale_state{status = Status} = State) ->
    State#sale_state{
        status      = evoq_bit_flags:set(Status, ?SALE_ARCHIVED),
        archived_at = get_value(archived_at, E)
    }.

%% --- Internal ---

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
