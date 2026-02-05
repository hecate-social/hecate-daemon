%%% @doc Projection: build_verified_v1 -> build_verifications table + projects flag
-module(build_verified_v1_to_build_verifications).

-export([project/1]).

%% @doc Project build_verified_v1 event to build_verifications table and set build_verified flag
-spec project(map()) -> ok | {error, term()}.
project(#{build_id := BId, project_id := PId} = E) ->
    InsertSql = "INSERT OR REPLACE INTO build_verifications "
                "(build_id, project_id, result, notes, verified_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5)",
    ok = query_alc_store:execute(InsertSql, [
        BId,
        PId,
        maps:get(result, E, <<"pass">>),
        maps:get(notes, E, undefined),
        maps:get(verified_at, E, erlang:system_time(millisecond))
    ]),
    FlagSql = "UPDATE projects SET build_verified = 1 "
              "WHERE project_id = ?1",
    query_alc_store:execute(FlagSql, [PId]).
