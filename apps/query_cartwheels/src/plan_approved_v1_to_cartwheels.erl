%%% @doc Projection: plan_approved_v1 -> cartwheels table (UPDATE plan_approved)
-module(plan_approved_v1_to_cartwheels).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{cartwheel_id := PId}) ->
    Sql = "UPDATE cartwheels SET plan_approved = 1 "
          "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(Sql, [PId]).
