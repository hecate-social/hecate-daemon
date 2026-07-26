%%% @doc EUnit tests for mesh_subscriptions_state.
-module(mesh_subscriptions_state_tests).

-include_lib("eunit/include/eunit.hrl").

-define(T1, <<"chat.demo">>).
-define(T2, <<"agents.module_generated">>).

%%--------------------------------------------------------------------
%% new/1
%%--------------------------------------------------------------------

new_returns_empty_topic_set_test() ->
    State = mesh_subscriptions_state:new(<<"mesh_subscriptions">>),
    ?assertEqual([], mesh_subscriptions_state:topics(State)),
    ?assertNot(mesh_subscriptions_state:has_topic(State, ?T1)).

%%--------------------------------------------------------------------
%% apply_event — added
%%--------------------------------------------------------------------

added_event_inserts_topic_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0, added(?T1)),
    ?assert(mesh_subscriptions_state:has_topic(S1, ?T1)),
    ?assertEqual([?T1], mesh_subscriptions_state:topics(S1)).

added_event_idempotent_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0, added(?T1)),
    S2 = mesh_subscriptions_state:apply_event(S1, added(?T1)),
    ?assertEqual([?T1], mesh_subscriptions_state:topics(S2)).

added_event_accumulates_topics_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0, added(?T1)),
    S2 = mesh_subscriptions_state:apply_event(S1, added(?T2)),
    ?assert(mesh_subscriptions_state:has_topic(S2, ?T1)),
    ?assert(mesh_subscriptions_state:has_topic(S2, ?T2)),
    ?assertEqual(lists:sort([?T1, ?T2]),
                 lists:sort(mesh_subscriptions_state:topics(S2))).

%%--------------------------------------------------------------------
%% apply_event — removed
%%--------------------------------------------------------------------

removed_event_drops_topic_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0, added(?T1)),
    S2 = mesh_subscriptions_state:apply_event(S1, removed(?T1)),
    ?assertNot(mesh_subscriptions_state:has_topic(S2, ?T1)),
    ?assertEqual([], mesh_subscriptions_state:topics(S2)).

removed_event_on_unsubscribed_is_noop_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0, removed(?T1)),
    ?assertEqual([], mesh_subscriptions_state:topics(S1)).

removed_event_keeps_other_topics_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0, added(?T1)),
    S2 = mesh_subscriptions_state:apply_event(S1, added(?T2)),
    S3 = mesh_subscriptions_state:apply_event(S2, removed(?T1)),
    ?assertNot(mesh_subscriptions_state:has_topic(S3, ?T1)),
    ?assert(mesh_subscriptions_state:has_topic(S3, ?T2)).

%%--------------------------------------------------------------------
%% apply_event — unknown shapes ignored
%%--------------------------------------------------------------------

unknown_event_is_ignored_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0,
        #{event_type => <<"unrelated_event_v1">>, topic => ?T1}),
    ?assertEqual([], mesh_subscriptions_state:topics(S1)).

missing_topic_field_is_ignored_test() ->
    S0 = mesh_subscriptions_state:new(<<>>),
    S1 = mesh_subscriptions_state:apply_event(S0,
        #{event_type => <<"mesh_subscription_added_v1">>}),
    ?assertEqual([], mesh_subscriptions_state:topics(S1)).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

added(Topic) ->
    #{event_type => <<"mesh_subscription_added_v1">>,
      topic => Topic,
      requested_at => erlang:system_time(millisecond)}.

removed(Topic) ->
    #{event_type => <<"mesh_subscription_removed_v1">>,
      topic => Topic,
      requested_at => erlang:system_time(millisecond)}.
