%%% @doc Subscription aggregate
%%% Maintains subscription state for an agent.
-module(subscription_aggregate).

-export([initial_state/0, execute/2, apply_event/2]).

-record(subscription_state, {
    agent_identity :: binary() | undefined,
    subscriptions :: #{binary() => map()},  %% topic => subscription_info
    total_subscriptions :: non_neg_integer()
}).

-opaque subscription_state() :: #subscription_state{}.
-export_type([subscription_state/0]).

%% @doc Initial empty state for evoq.
-spec initial_state() -> subscription_state().
initial_state() ->
    #subscription_state{
        agent_identity = undefined,
        subscriptions = #{},
        total_subscriptions = 0
    }.

%% @doc Execute command against aggregate state (evoq callback).
-spec execute(map(), subscription_state()) -> {ok, [map()]} | {error, term()}.
execute(#{command_type := subscribe} = Payload, _State) ->
    {ok, Cmd} = subscribe_v1:from_map(Payload),
    execute_handler(maybe_subscribe:handle(Cmd));
execute(#{command_type := unsubscribe} = Payload, _State) ->
    {ok, Cmd} = unsubscribe_v1:from_map(Payload),
    execute_handler(maybe_unsubscribe:handle(Cmd));
execute(_UnknownCommand, _State) ->
    {error, unknown_command}.

execute_handler({ok, Events}) ->
    EventMaps = [event_to_map(E) || E <- Events],
    {ok, EventMaps};
execute_handler({error, Reason}) ->
    {error, Reason}.

%% Events are always maps in this system
event_to_map(Event) when is_map(Event) -> Event.

%% @doc Apply event to aggregate state (snake_case_vN binary event types).
-spec apply_event(map(), subscription_state()) -> subscription_state().
apply_event(#{event_type := <<"subscribed_v1">>, agent_identity := Agent, topic := Topic, filter := Filter} = _Event, Agg) ->
    SubscriptionInfo = #{filter => Filter, subscribed => true},
    NewSubs = maps:put(Topic, SubscriptionInfo, Agg#subscription_state.subscriptions),
    Agg#subscription_state{
        agent_identity = Agent,
        subscriptions = NewSubs,
        total_subscriptions = maps:size(NewSubs)
    };

apply_event(#{event_type := <<"unsubscribed_v1">>, agent_identity := Agent, topic := Topic} = _Event, Agg) ->
    NewSubs = maps:remove(Topic, Agg#subscription_state.subscriptions),
    Agg#subscription_state{
        agent_identity = Agent,
        subscriptions = NewSubs,
        total_subscriptions = maps:size(NewSubs)
    };

apply_event(_OtherEvent, Agg) ->
    Agg.
