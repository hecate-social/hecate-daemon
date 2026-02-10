%%% @doc Projection: incident_raised_v1 -> incidents table
-module(incident_raised_v1_to_sqlite_incidents).
-export([project/1]).

project(Event) ->
    IncidentId = get(incident_id, Event),
    DivisionId = get(division_id, Event),
    IncidentTitle = get(incident_title, Event),
    Severity = get(severity, Event),
    Description = get(description, Event),
    RaisedAt = get(raised_at, Event),
    Sql = "INSERT OR REPLACE INTO incidents "
          "(incident_id, division_id, incident_title, severity, description, raised_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_monitoring_store:execute(Sql, [IncidentId, DivisionId, IncidentTitle,
                                        Severity, Description, RaisedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
