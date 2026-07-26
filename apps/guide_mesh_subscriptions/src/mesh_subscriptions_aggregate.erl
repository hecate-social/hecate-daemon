%%% @doc Aggregate for the mesh_subscriptions domain.
%%%
%%% Singleton per daemon. Stream: `mesh_subscriptions'. Accepts
%%% `add_mesh_subscription_v1' and `remove_mesh_subscription_v1'
%%% commands; produces `mesh_subscription_added_v1' /
%%% `mesh_subscription_removed_v1' events. Idempotent at this layer:
%%% adding an already-subscribed topic or removing an unsubscribed one
%%% produces an empty event list, so the dispatcher returns the
%%% existing stream version.
%%% @end
-module(mesh_subscriptions_aggregate).
-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/0]).

-spec state_module() -> module().
state_module() -> mesh_subscriptions_state.

-spec stream_id() -> binary().
stream_id() ->
    <<"mesh_subscriptions">>.

init(AggregateId) ->
    {ok, mesh_subscriptions_state:new(AggregateId)}.

%% evoq calls execute(State, Payload) — State FIRST.
execute(State,
        #{command_type := add_mesh_subscription_v1, topic := Topic} = Payload)
  when is_binary(Topic) ->
    case mesh_subscriptions_state:has_topic(State, Topic) of
        true  -> {ok, []};
        false -> maybe_add_mesh_subscription:handle_from_map(Payload)
    end;
execute(State,
        #{command_type := remove_mesh_subscription_v1, topic := Topic} = Payload)
  when is_binary(Topic) ->
    case mesh_subscriptions_state:has_topic(State, Topic) of
        false -> {ok, []};
        true  -> maybe_remove_mesh_subscription:handle_from_map(Payload)
    end;
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    mesh_subscriptions_state:apply_event(State, Event).
