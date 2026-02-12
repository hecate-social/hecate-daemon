%%% @doc Projection: incident_raised_v1 -> incidents table
-module(incident_raised_v1_to_sqlite_incidents).
-export([project/1]).

project(Event) ->
    IncidentId = get(incident_id, Event),
    DivisionId = get(division_id, Event),
    Title = get(title, Event),
    Severity = get(severity, Event),
    RaisedAt = get(raised_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, IncidentId]),
    Sql = "INSERT OR REPLACE INTO incidents "
          "(incident_id, division_id, title, severity, raised_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_division_alc_store:execute(Sql, [IncidentId, DivisionId, Title,
                                           Severity, RaisedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
