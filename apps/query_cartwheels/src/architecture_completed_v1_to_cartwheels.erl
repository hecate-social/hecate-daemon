%%% @doc Projection: architecture_completed_v1 -> cartwheels table (UPDATE status)
-module(architecture_completed_v1_to_cartwheels).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{cartwheel_id := PId}) ->
    Sql = "UPDATE cartwheels SET status = status | 16 "
          "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(Sql, [PId]).
