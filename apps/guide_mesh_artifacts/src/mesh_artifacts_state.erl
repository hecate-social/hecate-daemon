%%% @doc State module for mesh_artifacts aggregate.
%%%
%%% Singleton, append-only counter — same semantics as mesh_publications.
%%% No business rules over individual artifacts; the agent decides what
%%% to share. The aggregate exists so the event stream is well-ordered.
%%% @end
-module(mesh_artifacts_state).
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
apply_event(#state{count = N} = S, #{event_type := <<"mesh_artifact_shared_v1">>}) ->
    S#state{count = N + 1};
apply_event(S, _) ->
    S.

-spec to_map(state()) -> map().
to_map(#state{count = N}) ->
    #{count => N}.
