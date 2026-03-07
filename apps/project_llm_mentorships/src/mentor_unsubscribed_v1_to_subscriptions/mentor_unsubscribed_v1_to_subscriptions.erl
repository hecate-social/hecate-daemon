%%% @doc Projection: mentor_unsubscribed_v1 -> mentor_subscriptions ETS read model.
%%% Sets unsubscribed flag on existing subscription.
-module(mentor_unsubscribed_v1_to_subscriptions).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, mentor_subscriptions).

interested_in() -> [<<"mentor_unsubscribed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := #{subscriber_id := SId, mentor_id := MId}}, _Metadata, State, RM) ->
    Key = {SId, MId},
    case evoq_read_model:get(Key, RM) of
        {ok, Existing} ->
            Updated = Existing#{status => maps:get(status, Existing) bor 2},
            {ok, RM2} = evoq_read_model:put(Key, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.
