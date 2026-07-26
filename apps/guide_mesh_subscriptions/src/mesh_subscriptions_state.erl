%%% @doc State module for the mesh_subscriptions aggregate.
%%%
%%% Singleton aggregate. State is the set of currently-subscribed
%%% topics, rebuilt by replaying the event stream. Used by the
%%% aggregate's `execute/2' to enforce idempotency on add / remove
%%% (no-ops produce no event).
%%% @end
-module(mesh_subscriptions_state).
-behaviour(evoq_state).

-export([new/1, apply_event/2, to_map/1]).
-export([has_topic/2, topics/1]).

-record(state, {
    topics = sets:new([{version, 2}]) :: sets:set(binary())
}).

-type state() :: #state{}.
-export_type([state/0]).

-spec new(binary()) -> state().
new(_AggregateId) ->
    #state{}.

-spec apply_event(state(), map()) -> state().
apply_event(#state{topics = T} = S,
            #{event_type := <<"mesh_subscription_added_v1">>, topic := Topic})
  when is_binary(Topic) ->
    S#state{topics = sets:add_element(Topic, T)};
apply_event(#state{topics = T} = S,
            #{event_type := <<"mesh_subscription_removed_v1">>, topic := Topic})
  when is_binary(Topic) ->
    S#state{topics = sets:del_element(Topic, T)};
apply_event(S, _) ->
    S.

-spec has_topic(state(), binary()) -> boolean().
has_topic(#state{topics = T}, Topic) when is_binary(Topic) ->
    sets:is_element(Topic, T).

-spec topics(state()) -> [binary()].
topics(#state{topics = T}) ->
    sets:to_list(T).

-spec to_map(state()) -> map().
to_map(#state{topics = T}) ->
    #{topics => sets:to_list(T)}.
