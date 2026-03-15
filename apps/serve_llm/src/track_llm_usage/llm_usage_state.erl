%%% @doc State module for LLM usage aggregate.
%%%
%%% Owns the state record, event folding, and serialization.
%%% @end
-module(llm_usage_state).

-behaviour(evoq_state).

-include("llm_usage_state.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #llm_usage_state{}.
-export_type([state/0]).

%% @doc Create initial empty state.
-spec new(binary()) -> state().
new(_AggregateId) ->
    #llm_usage_state{}.

%% @doc Apply event to state. State FIRST, Event SECOND.
-spec apply_event(state(), map()) -> state().
apply_event(#llm_usage_state{call_count = N} = S,
            #{event_type := <<"llm_call_tracked_v1">>}) ->
    S#llm_usage_state{call_count = N + 1};
apply_event(S, _) ->
    S.

%% @doc Serialize state to map.
-spec to_map(state()) -> map().
to_map(#llm_usage_state{call_count = N}) ->
    #{call_count => N}.
