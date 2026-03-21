%%% @doc State module for site aggregate.
%%%
%%% Site = identity + nodes. Realm memberships are separate aggregates
%%% within site_store (not part of site state).
%%% @end
-module(site_state).

-behaviour(evoq_state).

-include("site_state.hrl").
-include("site_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #site_state{}.
-export_type([state/0]).

%% @doc Create initial empty state.
-spec new(binary()) -> state().
new(_AggregateId) ->
    #site_state{
        site_id = undefined,
        nodes = #{},
        status = 0,
        initiated_at = undefined
    }.

%% @doc Apply event to state. State FIRST, Event SECOND.
-spec apply_event(state(), map()) -> state().
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% @doc Serialize state to map.
-spec to_map(state()) -> map().
to_map(#site_state{} = S) ->
    #{
        site_id      => S#site_state.site_id,
        nodes        => S#site_state.nodes,
        status       => S#site_state.status,
        initiated_at => S#site_state.initiated_at
    }.

%% ===================================================================
%% Event application
%% ===================================================================

do_apply(<<"site_initiated_v1">>, State, Event) ->
    State#site_state{
        site_id = get_field(<<"site_id">>, site_id, Event),
        initiated_at = get_field(<<"initiated_at">>, initiated_at, Event),
        status = State#site_state.status bor ?SITE_INITIATED
    };

do_apply(<<"node_admitted_v1">>, State, Event) ->
    NodeName = get_field(<<"node_name">>, node_name, Event),
    AdmittedAt = get_field(<<"admitted_at">>, admitted_at, Event),
    Nodes = maps:put(NodeName, #{admitted_at => AdmittedAt}, State#site_state.nodes),
    State#site_state{nodes = Nodes};

do_apply(<<"node_removed_v1">>, State, Event) ->
    NodeName = get_field(<<"node_name">>, node_name, Event),
    Nodes = maps:remove(NodeName, State#site_state.nodes),
    State#site_state{nodes = Nodes};

do_apply(_UnknownType, State, _Event) ->
    State.

%% ===================================================================
%% Internal
%% ===================================================================

get_field(BinKey, AtomKey, Event) ->
    maps:get(BinKey, Event, maps:get(AtomKey, Event, undefined)).
