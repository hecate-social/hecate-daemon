%%% @doc Projection: term_defined_v1 -> terms table + cartwheels counter
-module(term_defined_v1_to_terms).

-export([project/1]).

%% @doc Project term_defined_v1 event to terms table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{term_id := TId, cartwheel_id := PId, term := Term, definition := Def} = E) ->
    InsertSql = "INSERT OR REPLACE INTO terms "
                "(term_id, cartwheel_id, term, definition, defined_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5)",
    ok = query_cartwheels_store:execute(InsertSql, [
        TId,
        PId,
        Term,
        Def,
        maps:get(defined_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE cartwheels SET term_count = term_count + 1 "
               "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(CountSql, [PId]).
