%%% @doc Projection: mentor_unsubscribed_v1 -> mentor_subscriptions table (UPDATE status)
-module(mentor_unsubscribed_v1_to_subscriptions).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{subscriber_id := SId, mentor_id := MId} = _E) ->
    Sql = "UPDATE mentor_subscriptions SET status = status | 2 "
          "WHERE subscriber_id = ?1 AND mentor_id = ?2",
    query_mentorships_store:execute(Sql, [SId, MId]).
