%%% @doc Projection: mentor_subscribed_v1 -> mentor_subscriptions table (INSERT)
-module(mentor_subscribed_v1_to_subscriptions).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{subscriber_id := SId, mentor_id := MId} = E) ->
    SubscribedAt = maps:get(subscribed_at, E, erlang:system_time(millisecond)),
    Sql = "INSERT OR REPLACE INTO mentor_subscriptions "
          "(subscriber_id, mentor_id, status, subscribed_at) "
          "VALUES (?1, ?2, 1, ?3)",
    query_mentorships_store:execute(Sql, [SId, MId, SubscribedAt]).
