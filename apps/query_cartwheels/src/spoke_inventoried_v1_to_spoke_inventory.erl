%%% @doc Projection: spoke_inventoried_v1 -> spoke_inventory table + cartwheels counter
-module(spoke_inventoried_v1_to_spoke_inventory).

-export([project/1]).

%% @doc Project spoke_inventoried_v1 event to spoke_inventory table and increment project counter
-spec project(map()) -> ok | {error, term()}.
project(#{spoke_id := SId, cartwheel_id := PId, spoke_name := Name, spoke_type := Type, dossier_id := DId} = E) ->
    InsertSql = "INSERT OR REPLACE INTO spoke_inventory "
                "(spoke_id, cartwheel_id, spoke_name, spoke_type, priority, dossier_id, description, inventoried_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
    ok = query_cartwheels_store:execute(InsertSql, [
        SId,
        PId,
        Name,
        Type,
        maps:get(priority, E, <<"should">>),
        DId,
        maps:get(description, E, undefined),
        maps:get(inventoried_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE cartwheels SET spoke_count = spoke_count + 1 "
               "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(CountSql, [PId]).
