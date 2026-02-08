%%% @doc Projection: testing_started_v1 -> cartwheels table (UPDATE phase_started_at)
-module(testing_started_v1_to_cartwheels).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{cartwheel_id := PId} = E) ->
    PhaseStartedAt = maps:get(started_at, E, erlang:system_time(millisecond)),
    Sql = "UPDATE cartwheels SET phase_started_at = ?1 "
          "WHERE cartwheel_id = ?2",
    query_cartwheels_store:execute(Sql, [PhaseStartedAt, PId]).
