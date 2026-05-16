%%% @doc State module for the mesh_publications aggregate.
%%%
%%% Singleton aggregate — the state is a monotonically incrementing
%%% publication counter. We do not enforce business rules over
%%% individual publications (the agent decides what's worth publishing);
%%% the aggregate exists to give the event a stream and the audit log
%%% a coherent order.
%%% @end
-module(mesh_publications_state).
-behaviour(evoq_state).

-export([new/1, apply_event/2, to_map/1]).

-record(state, {
    count = 0 :: non_neg_integer()
}).

-type state() :: #state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(_AggregateId) ->
    #state{count = 0}.

-spec apply_event(state(), map()) -> state().
apply_event(#state{count = N} = S, #{event_type := <<"mesh_fact_published_v1">>}) ->
    S#state{count = N + 1};
apply_event(S, _) ->
    S.

-spec to_map(state()) -> map().
to_map(#state{count = N}) ->
    #{count => N}.
