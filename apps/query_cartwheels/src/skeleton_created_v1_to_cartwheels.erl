%%% @doc Projection: skeleton_created_v1 -> cartwheels table (UPDATE skeleton_created)
-module(skeleton_created_v1_to_cartwheels).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{cartwheel_id := PId}) ->
    Sql = "UPDATE cartwheels SET skeleton_created = 1 "
          "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(Sql, [PId]).
