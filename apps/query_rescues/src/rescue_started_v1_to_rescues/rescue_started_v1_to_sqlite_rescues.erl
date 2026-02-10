%%% @doc Projection: rescue_started_v1 -> rescues table
-module(rescue_started_v1_to_sqlite_rescues).

-include_lib("rescue_division/include/rescue_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    IncidentId = get(incident_id, Event),
    StartedAt = get(started_at, Event),
    StartedBy = get(started_by, Event),
    Status = evoq_bit_flags:set(evoq_bit_flags:set(0, ?RESCUE_INITIATED), ?RESCUE_ACTIVE),
    StatusLabel = evoq_bit_flags:to_string(Status, ?RESCUE_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO rescues "
          "(division_id, incident_id, status, status_label, started_at, started_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_rescues_store:execute(Sql, [DivisionId, IncidentId, Status, StatusLabel, StartedAt, StartedBy]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
