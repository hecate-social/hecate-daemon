%%% @doc Projection: dependency_planned_v1 -> planned_dependencies table
-module(dependency_planned_v1_to_sqlite_planned_dependencies).
-export([project/1]).

project(Event) ->
    DependencyId = get(dependency_id, Event),
    DivisionId = get(division_id, Event),
    FromDesk = get(from_desk, Event),
    ToDesk = get(to_desk, Event),
    DependencyType = get(dependency_type, Event),
    Description = get(description, Event),
    PlannedBy = get(planned_by, Event),
    PlannedAt = get(planned_at, Event),
    Sql = "INSERT OR REPLACE INTO planned_dependencies "
          "(dependency_id, division_id, from_desk, to_desk, dependency_type, "
          "description, planned_by, planned_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
    query_plans_store:execute(Sql, [DependencyId, DivisionId, FromDesk, ToDesk,
                                    DependencyType, Description, PlannedBy, PlannedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
