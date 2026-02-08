%%% @doc Projection: dossier_defined_v1 -> dossier_designs table + cartwheels counter
-module(dossier_defined_v1_to_dossier_designs).

-export([project/1]).

%% @doc Project dossier_defined_v1 event to dossier_designs table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{dossier_id := DId, cartwheel_id := PId, dossier_name := Name} = E) ->
    InsertSql = "INSERT OR REPLACE INTO dossier_designs "
                "(dossier_id, cartwheel_id, dossier_name, stream_pattern, description, defined_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    ok = query_cartwheels_store:execute(InsertSql, [
        DId,
        PId,
        Name,
        maps:get(stream_pattern, E, <<"default">>),
        maps:get(description, E, undefined),
        maps:get(defined_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE cartwheels SET dossier_count = dossier_count + 1 "
               "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(CountSql, [PId]).
