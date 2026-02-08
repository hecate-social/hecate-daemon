%%% @doc Projection: finding_recorded_v1 -> findings table + cartwheels counter
-module(finding_recorded_v1_to_findings).

-export([project/1]).

%% @doc Project finding_recorded_v1 event to findings table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{finding_id := FId, cartwheel_id := PId, category := Cat, title := Title} = E) ->
    InsertSql = "INSERT OR REPLACE INTO findings "
                "(finding_id, cartwheel_id, category, title, content, priority, recorded_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    ok = query_cartwheels_store:execute(InsertSql, [
        FId,
        PId,
        Cat,
        Title,
        maps:get(content, E, undefined),
        maps:get(priority, E, <<"should">>),
        maps:get(recorded_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE cartwheels SET finding_count = finding_count + 1 "
               "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(CountSql, [PId]).
