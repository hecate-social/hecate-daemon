%%% @doc Projection: monitoring_started_v1 -> monitorings table
-module(monitoring_started_v1_to_sqlite_monitorings).

-include_lib("monitor_division/include/monitoring_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    StartedAt = get(started_at, Event),
    StartedBy = get(started_by, Event),
    Status = evoq_bit_flags:set(evoq_bit_flags:set(0, ?MONITORING_INITIATED), ?MONITORING_ACTIVE),
    StatusLabel = evoq_bit_flags:to_string(Status, ?MONITORING_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO monitorings "
          "(division_id, status, status_label, started_at, started_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_monitoring_store:execute(Sql, [DivisionId, Status, StatusLabel, StartedAt, StartedBy]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
