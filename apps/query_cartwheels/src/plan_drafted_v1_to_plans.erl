%%% @doc Projection: plan_drafted_v1 -> plans table
-module(plan_drafted_v1_to_plans).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{plan_id := PlId, cartwheel_id := PId, title := Title} = E) ->
    Sql = "INSERT OR REPLACE INTO plans "
          "(plan_id, cartwheel_id, title, content_ref, drafted_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_cartwheels_store:execute(Sql, [
        PlId,
        PId,
        Title,
        maps:get(content_ref, E, undefined),
        maps:get(drafted_at, E, erlang:system_time(millisecond))
    ]).
