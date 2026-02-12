%%% @doc Projection: dependency_planned_v1 -> planned_dependencies table
-module(dependency_planned_v1_to_sqlite_planned_dependencies).
-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    DependencyId = get(dependency_id, Event),
    FromDesk = get(from_desk, Event),
    ToDesk = get(to_desk, Event),
    DepType = get(dep_type, Event),
    PlannedAt = get(planned_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, DependencyId]),
    Sql = "INSERT OR REPLACE INTO planned_dependencies "
          "(division_id, dependency_id, from_desk, to_desk, "
          "dep_type, planned_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_division_alc_store:execute(Sql, [DivisionId, DependencyId, FromDesk,
                                           ToDesk, DepType, PlannedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
