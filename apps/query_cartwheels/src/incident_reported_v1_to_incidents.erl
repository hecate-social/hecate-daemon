%%% @doc Projection: incident_reported_v1 -> incidents table + cartwheels counter
-module(incident_reported_v1_to_incidents).

-export([project/1]).

%% @doc Project incident_reported_v1 event to incidents table and increment active_incidents counter
-spec project(map()) -> ok | {error, term()}.
project(#{incident_id := IncId, cartwheel_id := PId, description := Desc} = E) ->
    InsertSql = "INSERT OR REPLACE INTO incidents "
                "(incident_id, cartwheel_id, severity, description, reported_at) "
                "VALUES (?1, ?2, ?3, ?4, ?5)",
    ok = query_cartwheels_store:execute(InsertSql, [
        IncId,
        PId,
        maps:get(severity, E, <<"medium">>),
        Desc,
        maps:get(reported_at, E, erlang:system_time(millisecond))
    ]),
    CountSql = "UPDATE cartwheels SET active_incidents = active_incidents + 1 "
               "WHERE cartwheel_id = ?1",
    query_cartwheels_store:execute(CountSql, [PId]).
