%%% @doc Projection: build_verified_v1 -> build_verifications table + cartwheels flag
-module(build_verified_v1_to_build_verifications).

-export([project/1]).

%% @doc Project build_verified_v1 event to build_verifications table and set build_verified flag
-spec project(map()) -> ok | {error, term()}.
project(#{build_id := BId, cartwheel_id := PId} = E) ->
    InsertSql = "INSERT OR REPLACE INTO build_verifications "
                "(build_id, cartwheel_id, result, notes, verified_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5)",
    ok = query_cartwheels_store:execute(InsertSql, [
        BId,
        PId,
        maps:get(result, E, <<"pass">>),
        maps:get(notes, E, undefined),
        maps:get(verified_at, E, erlang:system_time(millisecond))
    ]),
    FlagSql = "UPDATE cartwheels SET build_verified = 1 "
              "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(FlagSql, [PId]).
