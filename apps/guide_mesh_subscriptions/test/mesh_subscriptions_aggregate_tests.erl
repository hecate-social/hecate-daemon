%%% @doc EUnit tests for mesh_subscriptions_aggregate execute/2.
%%%
%%% Focus: aggregate-level idempotency (re-add and re-remove return
%%% empty event lists when the state already matches the intent).
%%% @end
-module(mesh_subscriptions_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").

-define(T1, <<"chat.demo">>).

%%--------------------------------------------------------------------
%% add idempotency
%%--------------------------------------------------------------------

add_to_empty_state_produces_event_test() ->
    State = fresh(),
    {ok, Events} = mesh_subscriptions_aggregate:execute(State, add_cmd(?T1)),
    ?assertMatch([#{event_type := <<"mesh_subscription_added_v1">>,
                    topic := ?T1}], Events).

add_when_already_subscribed_is_noop_test() ->
    State = with_topic(?T1),
    {ok, Events} = mesh_subscriptions_aggregate:execute(State, add_cmd(?T1)),
    ?assertEqual([], Events).

%%--------------------------------------------------------------------
%% remove idempotency
%%--------------------------------------------------------------------

remove_when_subscribed_produces_event_test() ->
    State = with_topic(?T1),
    {ok, Events} = mesh_subscriptions_aggregate:execute(State, remove_cmd(?T1)),
    ?assertMatch([#{event_type := <<"mesh_subscription_removed_v1">>,
                    topic := ?T1}], Events).

remove_when_not_subscribed_is_noop_test() ->
    State = fresh(),
    {ok, Events} = mesh_subscriptions_aggregate:execute(State, remove_cmd(?T1)),
    ?assertEqual([], Events).

%%--------------------------------------------------------------------
%% unknown command
%%--------------------------------------------------------------------

unknown_command_rejected_test() ->
    State = fresh(),
    Payload = #{command_type => bogus_command_v1, topic => ?T1},
    ?assertEqual({error, unknown_command},
                 mesh_subscriptions_aggregate:execute(State, Payload)).

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

fresh() ->
    mesh_subscriptions_state:new(<<>>).

with_topic(Topic) ->
    mesh_subscriptions_state:apply_event(
        fresh(),
        #{event_type => <<"mesh_subscription_added_v1">>,
          topic => Topic,
          requested_at => erlang:system_time(millisecond)}).

add_cmd(Topic) ->
    #{command_type => add_mesh_subscription_v1,
      topic => Topic,
      requested_at => erlang:system_time(millisecond)}.

remove_cmd(Topic) ->
    #{command_type => remove_mesh_subscription_v1,
      topic => Topic,
      requested_at => erlang:system_time(millisecond)}.
