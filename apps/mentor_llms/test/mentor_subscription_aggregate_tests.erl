%%% @doc Tests for mentor_subscription_aggregate module.
-module(mentor_subscription_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

-record(subscription_state, {
    subscriber_id :: binary() | undefined,
    mentor_id     :: binary() | undefined,
    status        :: non_neg_integer(),
    subscribed_at :: non_neg_integer() | undefined
}).

-define(SUBSCRIBED,   1).
-define(UNSUBSCRIBED, 2).

%%% ===================================================================
%%% Helpers
%%% ===================================================================

subscribe_payload() ->
    #{command_type => <<"subscribe_to_mentor">>,
      subscriber_id => <<"agent-1">>,
      mentor_id => <<"mentor-1">>}.

unsubscribe_payload() ->
    #{command_type => <<"unsubscribe_from_mentor">>,
      subscriber_id => <<"agent-1">>,
      mentor_id => <<"mentor-1">>}.

subscribed_event() ->
    #{event_type => <<"mentor_subscribed_v1">>,
      subscriber_id => <<"agent-1">>,
      mentor_id => <<"mentor-1">>,
      subscribed_at => 1700000000000}.

unsubscribed_event() ->
    #{event_type => <<"mentor_unsubscribed_v1">>,
      subscriber_id => <<"agent-1">>,
      mentor_id => <<"mentor-1">>,
      unsubscribed_at => 1700000001000}.

%%% ===================================================================
%%% Tests
%%% ===================================================================

initial_state_test() ->
    State = mentor_subscription_aggregate:initial_state(),
    ?assertEqual(undefined, State#subscription_state.subscriber_id),
    ?assertEqual(undefined, State#subscription_state.mentor_id),
    ?assertEqual(0, State#subscription_state.status),
    ?assertEqual(undefined, State#subscription_state.subscribed_at).

execute_subscribe_to_mentor_test() ->
    State = mentor_subscription_aggregate:initial_state(),
    {ok, [EventMap]} = mentor_subscription_aggregate:execute(State, subscribe_payload()),
    ?assertEqual(<<"mentor_subscribed_v1">>, maps:get(event_type, EventMap)),
    ?assertEqual(<<"agent-1">>, maps:get(subscriber_id, EventMap)),
    ?assertEqual(<<"mentor-1">>, maps:get(mentor_id, EventMap)),
    ?assert(is_integer(maps:get(subscribed_at, EventMap))).

execute_subscribe_already_subscribed_test() ->
    State0 = mentor_subscription_aggregate:initial_state(),
    State1 = mentor_subscription_aggregate:apply(State0, subscribed_event()),
    ?assertEqual(?SUBSCRIBED, State1#subscription_state.status),
    ?assertEqual({error, already_subscribed},
                 mentor_subscription_aggregate:execute(State1, subscribe_payload())).

apply_mentor_subscribed_v1_test() ->
    State0 = mentor_subscription_aggregate:initial_state(),
    State1 = mentor_subscription_aggregate:apply(State0, subscribed_event()),
    ?assertEqual(<<"agent-1">>, State1#subscription_state.subscriber_id),
    ?assertEqual(<<"mentor-1">>, State1#subscription_state.mentor_id),
    ?assertEqual(?SUBSCRIBED, State1#subscription_state.status),
    ?assertEqual(1700000000000, State1#subscription_state.subscribed_at).

execute_unsubscribe_test() ->
    State0 = mentor_subscription_aggregate:initial_state(),
    State1 = mentor_subscription_aggregate:apply(State0, subscribed_event()),
    {ok, [EventMap]} = mentor_subscription_aggregate:execute(State1, unsubscribe_payload()),
    ?assertEqual(<<"mentor_unsubscribed_v1">>, maps:get(event_type, EventMap)),
    ?assertEqual(<<"agent-1">>, maps:get(subscriber_id, EventMap)),
    ?assertEqual(<<"mentor-1">>, maps:get(mentor_id, EventMap)).

execute_unsubscribe_not_subscribed_test() ->
    State = mentor_subscription_aggregate:initial_state(),
    ?assertEqual({error, not_subscribed},
                 mentor_subscription_aggregate:execute(State, unsubscribe_payload())).

execute_unsubscribe_already_unsubscribed_test() ->
    %% Build state: subscribed then unsubscribed
    State0 = mentor_subscription_aggregate:initial_state(),
    State1 = mentor_subscription_aggregate:apply(State0, subscribed_event()),
    State2 = mentor_subscription_aggregate:apply(State1, unsubscribed_event()),
    ?assertEqual(?SUBSCRIBED bor ?UNSUBSCRIBED, State2#subscription_state.status),
    ?assertEqual({error, already_unsubscribed},
                 mentor_subscription_aggregate:execute(State2, unsubscribe_payload())).

apply_mentor_unsubscribed_v1_test() ->
    State0 = mentor_subscription_aggregate:initial_state(),
    State1 = mentor_subscription_aggregate:apply(State0, subscribed_event()),
    State2 = mentor_subscription_aggregate:apply(State1, unsubscribed_event()),
    %% SUBSCRIBED bor UNSUBSCRIBED = 1 bor 2 = 3
    ?assertEqual(?SUBSCRIBED bor ?UNSUBSCRIBED, State2#subscription_state.status),
    ?assertEqual(3, State2#subscription_state.status).

resubscribe_after_unsubscribe_test() ->
    %% Build state: subscribed -> unsubscribed
    State0 = mentor_subscription_aggregate:initial_state(),
    State1 = mentor_subscription_aggregate:apply(State0, subscribed_event()),
    State2 = mentor_subscription_aggregate:apply(State1, unsubscribed_event()),
    ?assertEqual(?SUBSCRIBED bor ?UNSUBSCRIBED, State2#subscription_state.status),
    %% Re-subscribe should succeed
    {ok, [EventMap]} = mentor_subscription_aggregate:execute(State2, subscribe_payload()),
    ?assertEqual(<<"mentor_subscribed_v1">>, maps:get(event_type, EventMap)),
    ?assertEqual(<<"agent-1">>, maps:get(subscriber_id, EventMap)),
    ?assertEqual(<<"mentor-1">>, maps:get(mentor_id, EventMap)).
