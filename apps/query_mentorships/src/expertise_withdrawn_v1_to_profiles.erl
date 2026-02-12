%%% @doc Projection: expertise_withdrawn_v1 -> mentor_profiles table (UPDATE status)
-module(expertise_withdrawn_v1_to_profiles).

-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(#{agent_id := AId} = _E) ->
    Sql = "UPDATE mentor_profiles SET status = status | 2 WHERE agent_id = ?1",
    query_mentorships_store:execute(Sql, [AId]).
