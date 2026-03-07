%%% @doc Projection: mentor_subscribed_v1 -> mentor_subscriptions ETS read model.
%%% Inserts a subscription record.
-module(mentor_subscribed_v1_to_subscriptions).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, mentor_subscriptions).

interested_in() -> [<<"mentor_subscribed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := #{subscriber_id := SId, mentor_id := MId} = Data}, _Metadata, State, RM) ->
    Key = {SId, MId},
    Sub = #{
        subscriber_id => SId,
        mentor_id     => MId,
        status        => 1,
        subscribed_at => maps:get(subscribed_at, Data, erlang:system_time(millisecond))
    },
    {ok, RM2} = evoq_read_model:put(Key, Sub, RM),
    {ok, State, RM2}.
