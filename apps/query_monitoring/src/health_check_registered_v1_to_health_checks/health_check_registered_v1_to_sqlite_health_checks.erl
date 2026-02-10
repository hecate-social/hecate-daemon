%%% @doc Projection: health_check_registered_v1 -> health_checks table
-module(health_check_registered_v1_to_sqlite_health_checks).
-export([project/1]).

project(Event) ->
    CheckId = get(check_id, Event),
    DivisionId = get(division_id, Event),
    CheckName = get(check_name, Event),
    CheckType = get(check_type, Event),
    Endpoint = get(endpoint, Event),
    IntervalMs = get(interval_ms, Event),
    RegisteredAt = get(registered_at, Event),
    Sql = "INSERT OR REPLACE INTO health_checks "
          "(check_id, division_id, check_name, check_type, endpoint, "
          "interval_ms, registered_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    query_monitoring_store:execute(Sql, [CheckId, DivisionId, CheckName, CheckType,
                                        Endpoint, IntervalMs, RegisteredAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
