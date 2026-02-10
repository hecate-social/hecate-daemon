%%% @doc Projection: desk_planned_v1 -> planned_desks table
-module(desk_planned_v1_to_sqlite_planned_desks).
-export([project/1]).

project(Event) ->
    DeskId = get(desk_id, Event),
    DivisionId = get(division_id, Event),
    DeskName = get(desk_name, Event),
    Department = get(department, Event),
    AggregateName = get(aggregate_name, Event),
    Description = get(description, Event),
    Priority = get(priority, Event),
    PlannedBy = get(planned_by, Event),
    PlannedAt = get(planned_at, Event),
    Sql = "INSERT OR REPLACE INTO planned_desks "
          "(desk_id, division_id, desk_name, department, aggregate_name, "
          "description, priority, planned_by, planned_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
    query_plans_store:execute(Sql, [DeskId, DivisionId, DeskName, Department,
                                    AggregateName, Description, Priority,
                                    PlannedBy, PlannedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
