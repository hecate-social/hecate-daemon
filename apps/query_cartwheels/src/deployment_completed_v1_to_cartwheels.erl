%%% @doc Projection: deployment_completed_v1 -> cartwheels table (UPDATE status bit flag + completed_at)
-module(deployment_completed_v1_to_cartwheels).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{cartwheel_id := PId} = E) ->
    CompletedAt = maps:get(completed_at, E, erlang:system_time(millisecond)),
    Sql = "UPDATE cartwheels SET status = status | 256, completed_at = ?1 "
          "WHERE cartwheel_id = ?2",
    query_cartwheels_store:execute(Sql, [CompletedAt, PId]).
