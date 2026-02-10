%%% @doc Projection: health_status_recorded_v1 -> health_checks table (UPDATE last status)
-module(health_status_recorded_v1_to_sqlite_health_checks).
-export([project/1]).

project(Event) ->
    CheckId = get(check_id, Event),
    LastStatus = get(last_status, Event),
    LastLatencyMs = get(last_latency_ms, Event),
    LastCheckedAt = get(last_checked_at, Event),
    Sql = "UPDATE health_checks SET last_status = ?1, last_latency_ms = ?2, "
          "last_checked_at = ?3 WHERE check_id = ?4",
    query_monitoring_store:execute(Sql, [LastStatus, LastLatencyMs, LastCheckedAt, CheckId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
